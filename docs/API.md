# API Design

**Status:** Design v1 · Base: `https://api.tapid.app/v1`

REST over API Gateway HTTP API. JSON only. All timestamps RFC 3339 UTC.

---

## Auth model

The unusual part of this system, and worth understanding before the endpoints:
**door staff share devices.** A phone sits at the front door and three different
people use it over one night. Modeling that as "user logs in" produces a
worthless audit trail, because the session outlives the person.

So authentication is split in two:

### 1. Device credential — long-lived, hardware-bound

A device is enrolled once by a manager. It receives a refresh credential bound
to the device's App Attest key, held in the iOS Keychain with
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. It is not exportable and not
transferable to another device.

The device credential alone can do almost nothing: refresh its token, fetch
config, and submit events **for an active shift**. It cannot read history,
change settings, or enroll other devices.

### 2. Shift claim — short-lived, human-bound

A staff member claims the device at the start of their shift with a 6-digit PIN
(or Face ID if the device is assigned to one person). This opens a `Shift`, and
every event submitted while it is open is attributed to that human.

```
POST /shifts          → claim device, open shift   (PIN)
POST /shifts/current/end → close shift
```

Shifts auto-close after a configurable idle period (default 10h) so a forgotten
shift doesn't attribute the next night's checks to yesterday's bouncer.

Manager and owner roles use ordinary Cognito auth with MFA for the dashboard —
a completely separate path from the door app.

### Request signing

Every request from a verifier device carries:

```
Authorization: Bearer <device access token, 60min TTL>
X-TapID-Attestation: <App Attest assertion over SHA256(body)>
X-TapID-Attest-Counter: <monotonic counter>
X-Idempotency-Key: <client ULID>
```

A Lambda authorizer validates the assertion against the device's stored public
key and rejects any counter that does not strictly increase. This is what makes
a submitted event evidence rather than a claim — see
[`THREAT_MODEL.md`](THREAT_MODEL.md#t1-forged-attestations).

---

## Endpoints

### `POST /events:batch` — the hot path

The only high-volume endpoint. The client drains its outbox in batches of up to
50, so a busy door produces a few requests per minute rather than one per tap.

```jsonc
// Request
{
  "events": [
    {
      "eventId": "01H8XQVK7C9ZJ4M2N5P8R3T6W",   // client ULID
      "shiftId": "sft_01H8C",
      "railResult": "approved",
      "ageAtLeast21": true,
      "humanDecision": "allowed",
      "refusalReason": null,
      "issuingJurisdiction": "CA",
      "credentialType": "apple_wallet_mdl",
      "occurredAt": "2026-07-29T04:12:33.412Z",
      "readLatencyMs": 1840,
      "syncedOffline": true
    }
  ]
}
```

```jsonc
// 200 — per-item results; a partial failure must not fail the batch
{
  "results": [
    { "eventId": "01H8XQ...", "status": "accepted" },
    { "eventId": "01H8XR...", "status": "duplicate" },   // already ingested — client may purge
    { "eventId": "01H8XS...", "status": "rejected",
      "error": { "code": "shift_not_found", "retryable": false } }
  ]
}
```

**Per-item results are essential.** One bad event in a batch of 50 must not
block the other 49, and the client needs to know precisely which items to purge
versus retry. A batch endpoint that returns a single status code forces the
client to either drop good data or retry duplicates forever.

`duplicate` is a **success** from the client's perspective — it means the server
already has it, so purge locally. This is what makes retries safe.

Rejections are explicitly tagged `retryable` so the client never spins on a
permanent failure (a malformed event) or gives up on a transient one (throttling).

### Configuration

```
GET /config
```

Returns the AppConfig-backed operational parameters. Cached locally with a TTL so
it works offline.

```jsonc
{
  "version": 47,
  "supportedJurisdictions": ["AZ","CA","CO","GA","HI","IA","MD","MT","NM","OH","PR","WV"],
  "minimumAge": 21,                    // per-venue; some jurisdictions differ
  "requestedElements": ["age_at_least_21","portrait","given_name","family_name"],
  "shiftIdleTimeoutMinutes": 600,
  "outboxWarnThreshold": 10000,
  "flags": { "railEnabled": true, "mockRailAllowed": false }
}
```

`supportedJurisdictions` being server-driven is the highest-value flag in the
system: Apple adds states on their own schedule, and hardcoding this list would
mean an App Store release every time. `railEnabled` is the kill switch if Apple
changes something under us.

### Venue & fleet management

```
GET    /venues                        list venues in org
GET    /venues/{id}                   settings, timezone, minimum age
PATCH  /venues/{id}                   update settings              [manager]
GET    /venues/{id}/summary?from=&to= daily rollups — never raw events
GET    /venues/{id}/events?date=      one venue-day of raw events  [manager]

POST   /devices                       enroll device (attestation)  [manager]
GET    /devices                       fleet status
POST   /devices/{id}:revoke           kill a lost/stolen device    [manager]

GET    /staff                         roster
POST   /staff                         add member                   [manager]
POST   /staff/{id}:rotate-pin                                      [manager]
```

`POST /devices/{id}:revoke` matters more than it looks: a door iPhone is a
frequently-lost object in a loud dark room. Revocation invalidates the device
credential immediately and is auditable.

### Compliance export — async by design

```
POST /exports                         { from, to, venueIds[], format }
GET  /exports/{id}                    → status, then presigned S3 URL
```

Exports are asynchronous and served from the S3/Athena lake, never from
DynamoDB. A liquor-board request covering two years must not be able to
degrade the door experience on a Saturday night. This separation is deliberate.

---

## Error contract

```jsonc
{
  "error": {
    "code": "attestation_invalid",
    "message": "Device attestation could not be verified.",
    "retryable": false,
    "requestId": "01H8XQVK..."       // always present, for support
  }
}
```

| Code | HTTP | Retryable | Meaning |
|---|---|---|---|
| `attestation_invalid` | 401 | no | Assertion failed — possible tampering |
| `attestation_counter_replay` | 401 | no | Counter did not increase — replay |
| `device_revoked` | 403 | no | Wipe local state, return to enrollment |
| `shift_not_found` | 409 | no | Event references a closed/unknown shift |
| `clock_skew_excessive` | 409 | no | Device clock implausible; prompt resync |
| `rate_limited` | 429 | **yes** | Back off per `Retry-After` |
| `internal` | 500 | **yes** | Transient |

The client's sync loop branches solely on `retryable`, so a new error code never
requires a client release to be handled safely.

## Versioning

URL-versioned (`/v1`). Additive changes only within a version. Because door
devices may be offline or un-updated for weeks, **any given API version must be
supported for at least 12 months** after its successor ships. The batch ingest
contract in particular should be treated as near-frozen — it is the one endpoint
an old client cannot avoid calling.

## Rate limits

| Scope | Limit |
|---|---|
| Per device, `/events:batch` | 60 req/min (≈3,000 events/min) |
| Per device, all others | 30 req/min |
| Per org, aggregate | 10,000 req/min (raisable) |

Limits are generous on the ingest path and tight elsewhere: throttling a door
device mid-rush would push events back into the outbox and eventually surface as
a stale dashboard, so the ingest path should effectively never throttle in
normal operation.
