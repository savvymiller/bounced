# Data Model — DynamoDB Single Table

**Status:** Design v1

One table, `tapid-main`, on-demand billing. The access patterns are narrow and
known, which is exactly when single-table design pays off.

**The defining property of this schema: there is nowhere to put PII.** No name
field, no DOB field, no portrait field, no document identifier. Zero-retention
is enforced by the absence of columns, not by a policy someone has to remember.
Adding such a field requires an ADR and a compliance review — see
[ADR-0003](adr/0003-zero-retention.md).

---

## Key design

| | Partition Key (PK) | Sort Key (SK) |
|---|---|---|
| Organization | `ORG#{orgId}` | `META` |
| Venue | `ORG#{orgId}` | `VENUE#{venueId}` |
| Staff member | `ORG#{orgId}` | `STAFF#{staffId}` |
| Device | `ORG#{orgId}` | `DEVICE#{deviceId}` |
| Shift | `VENUE#{venueId}` | `SHIFT#{startIso}#{shiftId}` |
| Verification event | `VENUE#{venueId}#{yyyy-mm-dd}` | `EVT#{ulid}` |
| Daily rollup | `VENUE#{venueId}` | `ROLLUP#{yyyy-mm-dd}` |
| Idempotency marker | `IDEM#{eventId}` | `IDEM` |

Every tenant-scoped key begins with `ORG#` or `VENUE#`, which lets a single IAM
policy enforce isolation via `dynamodb:LeadingKeys`. A code bug cannot read
another tenant's data because IAM refuses the request.

### Why events are partitioned by venue **and day**

`VENUE#{venueId}#{yyyy-mm-dd}` bounds each partition to one venue-day. A single
busy venue writing 2,000 events on a Saturday stays far under per-partition
write limits, and "show me last night at this location" — the most common
dashboard query — is a single efficient `Query` with no filter. A pure
`VENUE#{venueId}` partition would grow unboundedly and eventually go hot.

### Global secondary indexes

| Index | PK | SK | Serves |
|---|---|---|---|
| `GSI1` | `ORG#{orgId}` | `EVT#{timestamp}` | Chain-wide activity across all venues |
| `GSI2` | `DEVICE#{deviceId}` | `EVT#{timestamp}` | Per-device audit, fraud investigation |
| `GSI3` | `STAFF#{staffId}` | `SHIFT#{startIso}` | "What did this employee work?" |

Three GSIs is the ceiling I'd hold to for v1. Additional query needs should be
served by rollups or the S3/Athena lake, not by more indexes.

---

## Item shapes

### VerificationEvent — the core record

```jsonc
{
  "PK": "VENUE#v_01H8X#2026-07-29",
  "SK": "EVT#01H8XQVK7C9ZJ4M2N5P8R3T6W",   // client ULID = idempotency key
  "type": "VerificationEvent",

  "orgId": "org_01H8A",
  "venueId": "v_01H8X",
  "deviceId": "dev_01H8B",
  "shiftId": "sft_01H8C",
  "staffId": "stf_01H8D",

  // --- outcome ---
  "railResult": "approved",        // approved | declined | expired |
                                   // unsupportedIssuer | readFailed | cancelled
  "ageAtLeast21": true,            // authoritative, from issuer signature
  "humanDecision": "allowed",      // allowed | refused  (attendant's call)
  "refusalReason": null,           // optional, from a fixed enum
  "issuingJurisdiction": "CA",     // coarse: state only, never a doc number
  "credentialType": "apple_wallet_mdl",

  // --- provenance / integrity ---
  "occurredAt": "2026-07-29T04:12:33.412Z",  // device clock
  "receivedAt": "2026-07-29T04:12:51.006Z",  // server clock
  "clockSkewMs": 1180,                        // flagged if implausible
  "readLatencyMs": 1840,
  "appVersion": "1.0.3",
  "osVersion": "18.2",
  "attestationVerified": true,
  "syncedOffline": true,           // was this queued rather than live?

  "ttl": 1785000000                // 90-day hot window; S3 is the archive
}
```

`occurredAt` comes from a device the venue controls, so it is not fully
trustworthy. Storing `receivedAt` and `clockSkewMs` alongside it lets us detect
tampering (a device replaying old events, or backdating to fake a check) without
rejecting legitimately offline-queued events. Large skew is a signal, not an
error.

### Device — the integrity anchor

```jsonc
{
  "PK": "ORG#org_01H8A",
  "SK": "DEVICE#dev_01H8B",
  "type": "Device",
  "venueId": "v_01H8X",
  "label": "Front Door iPhone",
  "attestKeyId": "base64...",         // App Attest public key handle
  "attestReceipt": "base64...",       // for periodic re-validation w/ Apple
  "attestCounter": 84213,             // must increase monotonically
  "status": "active",                 // active | suspended | revoked
  "model": "iPhone14,5",
  "railCapable": true,                // passes iPhone XS+ / iOS 17+ check
  "enrolledAt": "2026-06-01T18:00:00Z",
  "lastSeenAt": "2026-07-29T04:12:51Z"
}
```

`attestCounter` is the replay defense: assertions must arrive with a
strictly increasing counter. A repeat or regression means a replayed or cloned
request. See [`THREAT_MODEL.md`](THREAT_MODEL.md#t1-forged-attestations).

### Shift — what makes the audit trail defensible

```jsonc
{
  "PK": "VENUE#v_01H8X",
  "SK": "SHIFT#2026-07-28T20:00:00Z#sft_01H8C",
  "type": "Shift",
  "staffId": "stf_01H8D",
  "deviceId": "dev_01H8B",
  "startedAt": "2026-07-28T20:00:00Z",
  "endedAt": "2026-07-29T02:30:00Z",
  "endedBy": "auto_timeout",       // manual | auto_timeout | shift_handoff
  "eventCount": 412
}
```

Door staff share devices and rotate mid-night. Modeling the human/device/venue
binding as a time-boxed shift — rather than a login session — is what lets a
venue answer "who checked this person at 12:40am" months later during a
compliance audit. This is the record a liquor board actually asks for.

### DailyRollup — computed, never queried live

```jsonc
{
  "PK": "VENUE#v_01H8X",
  "SK": "ROLLUP#2026-07-28",
  "type": "DailyRollup",
  "total": 412,
  "approved": 388,
  "refused": 9,
  "underage": 3,
  "expired": 2,
  "unsupportedIssuer": 7,          // → demand signal for the barcode rail
  "readFailed": 3,
  "p50ReadLatencyMs": 1620,
  "p95ReadLatencyMs": 2980,
  "peakHourLocal": 23
}
```

Written by a DynamoDB Streams consumer with atomic `ADD` updates. Dashboards
read rollups only — **never a scan or a full-day query**. This is what keeps
dashboard cost and latency flat as venues grow.

`unsupportedIssuer` deserves special attention: aggregated across venues it
directly quantifies how much coverage the barcode rail would add, and which
states to prioritize. A metric that turns a v1 limitation into roadmap evidence.

---

## Access patterns → implementation

| # | Pattern | Implementation |
|---|---|---|
| 1 | Ingest a batch of events idempotently | `TransactWriteItems` w/ `attribute_not_exists(PK)` on the idempotency marker |
| 2 | Tonight's activity at a venue | `Query PK = VENUE#{id}#{today}` |
| 3 | Venue trend, last 30 days | `Query PK = VENUE#{id}, SK begins_with ROLLUP#` |
| 4 | Chain-wide recent activity | `Query GSI1 PK = ORG#{id}` |
| 5 | Audit one device | `Query GSI2 PK = DEVICE#{id}` |
| 6 | Staff shift history | `Query GSI3 PK = STAFF#{id}` |
| 7 | Venue roster & settings | `Query PK = ORG#{id}, SK begins_with VENUE#` / `STAFF#` |
| 8 | Compliance export, arbitrary range | Athena over S3 Parquet — not DynamoDB |
| 9 | Active shift for a device | `Query PK = VENUE#{id}, SK begins_with SHIFT#`, filter `endedAt` null |

Pattern 8 is the important boundary: DynamoDB serves the operational hot path
(90 days), S3 + Athena serves unbounded historical and regulatory queries. Never
let a compliance export hit the operational table.

---

## Retention and lifecycle

| Store | Retention | Rationale |
|---|---|---|
| DynamoDB | 90 days, native TTL | Operational window; keeps table small and fast |
| S3 (Parquet, date-partitioned) | 7 years, Glacier after 1 year | Alcohol-service recordkeeping obligations often run multi-year |
| Client outbox | Until ack'd, then purged | Nothing lingers on a device that can be lost or stolen |
| CloudWatch Logs | 30 days | Structured, and PII-free by construction |

Because no record contains PII, long retention is a low-risk proposition — a
breach of the archive discloses that a check occurred, not who was checked.
That property is the entire point of [ADR-0003](adr/0003-zero-retention.md).
