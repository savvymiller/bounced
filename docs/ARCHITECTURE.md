# TapID — System Architecture

**Status:** Design v1 · **Last updated:** 2026-07-29

TapID lets a door attendant verify a patron's age by having the patron tap their
iPhone (Apple Wallet ID) against the attendant's iPhone. The attendant sees a
portrait plus the minimum identity fields needed to match the person in front of
them, and an authoritative `age_at_least_21` boolean cryptographically attested
by the issuing state.

This document is the source of truth for the v1 architecture. Decisions with
meaningful trade-offs are recorded as ADRs in [`adr/`](adr/) and referenced inline.

---

## 1. The constraint that shapes everything

Apple's ID Verifier lives in the **ProximityReader** framework — the same
framework behind Tap to Pay on iPhone. Four properties of it drive most of the
design:

| Property | Consequence for TapID |
|---|---|
| Requires an Apple-granted entitlement + business vetting | We cannot run the real rail until Apple approves us. Development must not block on that. → [ADR-0002](adr/0002-mock-rail-parity.md) |
| Verifier device must be a **physical iPhone** (XS or later, iOS 17+) | No iPad, no Android, no Simulator. The verifier device fleet is narrow and must be enforced in software. |
| The tap flow is a **native, Apple-owned UI sheet** | Flutter cannot draw it. The tap is Swift; Flutter owns everything around it. → [ADR-0001](adr/0001-flutter-plus-native-tap.md) |
| Display-only tier **forbids retaining or transmitting** the returned data | Zero-retention is not just our policy, it is Apple's contract term. → [ADR-0003](adr/0003-zero-retention.md) |

Two prior prototypes in this workspace (`BouncerCheck/`, `id-check/`) both
stalled at the entitlement wall with a stubbed verifier. v1 treats the
entitlement as a **long-lead external dependency** and makes every layer above
it testable without it.

### Apple's two tiers

| | Display Only | Data Transfer |
|---|---|---|
| Entitlement | `com.apple.developer.proximity-reader.identity.display` | `com.apple.developer.proximity-reader.identity.read` |
| Data reaches our code | No — Apple renders it | Yes — returned to the app |
| Retention | Prohibited | Contractually constrained |
| Vetting burden | Lower | Higher (separate agreement) |

**v1 targets Display Only.** It is the faster approval path and it structurally
guarantees the zero-retention posture. The bouncer's eyes do the face match;
our app never touches the portrait bytes. See [ADR-0004](adr/0004-display-only-tier.md)
for the upgrade path to Data Transfer and what it would unlock.

> ⚠️ **Exact ProximityReader symbol names and initializer signatures must be
> pinned against the SDK version you build with.** The entitlement strings and
> overall session shape above are stable; the precise Swift API surface has
> moved between iOS releases. Verify in Xcode before writing the real rail —
> do not trust any signature reproduced from memory, including in this repo's
> skeleton files.

---

## 2. System context

```
┌─────────────────┐         NFC tap          ┌──────────────────────┐
│  Patron iPhone  │ ───────────────────────► │  Verifier iPhone     │
│  Apple Wallet   │   issuer-signed mdoc     │  TapID app           │
│  state mDL      │ ◄─────────────────────── │  (Flutter + Swift)   │
└─────────────────┘      reader token        └──────────┬───────────┘
        ▲                                               │
        │ provisioned by                                │ attestation only
        │                                               │ (no PII)
┌───────┴─────────┐                          ┌──────────▼───────────┐
│  Issuing state  │                          │  AWS backend         │
│  DMV / AAMVA    │                          │  multi-tenant API    │
└─────────────────┘                          └──────────┬───────────┘
                                                        │
                              ┌─────────────────────────┼──────────────────┐
                              ▼                         ▼                  ▼
                       Venue web dashboard      Analytics lake      Webhooks/POS
```

**Trust anchor:** the issuing state signs the credential; Apple's OS validates
that signature inside the Secure Element before showing anything. TapID is not
in the business of validating documents — it is in the business of *recording
that a valid check happened* and giving venues an auditable, defensible trail.
That reframing is the actual product.

---

## 3. Component architecture

### 3.1 Client — Flutter shell + native verification module

```
apps/verifier_app/
├── lib/
│   ├── core/              # DI, config, logging, result types
│   ├── data/
│   │   ├── local/         # Drift + SQLCipher: outbox, roster cache, session
│   │   ├── remote/        # API client, retry/backoff, App Attest signing
│   │   └── sync/          # Outbox drain, conflict policy, connectivity
│   ├── domain/
│   │   ├── entities/      # VerificationOutcome, Venue, Shift, StaffMember
│   │   ├── rails/         # VerificationRail interface  ← single seam
│   │   └── usecases/      # PerformCheck, RecordDecision, StartShift
│   └── features/          # auth, door (main tap screen), history, settings
└── ios/Runner/Verification/
    ├── VerificationBridge.swift     # Pigeon-generated channel
    ├── AppleWalletRail.swift        # real ProximityReader impl
    ├── MockRail.swift               # deterministic fixtures
    └── RedactionBoundary.swift      # enforces the DTO contract
```

**The platform channel is the privacy boundary.** Swift receives whatever Apple
gives it; the channel is only allowed to emit this DTO, and nothing else:

```dart
class VerificationOutcome {
  final String eventId;          // client ULID, idempotency key
  final RailResult result;       // approved | declined | expired |
                                 // unsupportedIssuer | readFailed | cancelled
  final bool? ageAtLeast21;      // authoritative, from issuer signature
  final String? issuingJurisdiction; // "CA" — coarse, not a document number
  final DateTime occurredAt;
  final Duration readLatency;
  // NO name. NO date of birth. NO portrait. NO document identifier.
}
```

Because the DTO has no PII fields, PII cannot leak through this layer even by
accident. Enforced by a codegen'd contract (Pigeon) plus a CI check that fails
on new fields in the outcome DTO without an ADR reference. See
[`THREAT_MODEL.md`](THREAT_MODEL.md#t4-pii-leakage-via-client-logs).

**Why Flutter is still the right call** even though the tap is native: the tap
screen is ~10% of the app. Auth, shift management, venue settings, history,
incident notes, staff roster, offline queue UI, and the eventual Android
build for non-tap features are all Flutter. One codebase for the 90%.
[ADR-0001](adr/0001-flutter-plus-native-tap.md).

**Offline-first.** Verification is fully local — the OS validates the issuer
signature with no network involved. A dead-zone basement must not stop the
door. Outcomes land in an encrypted local outbox and drain opportunistically.
[ADR-0005](adr/0005-offline-first-outbox.md).

**Device integrity.** Each outcome is signed with an App Attest assertion so the
backend can distinguish a genuine TapID binary from a script POSTing fabricated
"approved" events. Without this, the audit trail is worthless — which is the
whole product. See [`THREAT_MODEL.md`](THREAT_MODEL.md#t1-forged-attestations).

### 3.2 Backend — AWS, burst-shaped

Nightlife traffic is extreme: near-zero Monday 10am, thousands of taps per
minute Saturday 11pm–1am, with a hard spike at close. Roughly **95% of annual
volume arrives in ~6 hours per week.**

That shape argues strongly for serverless. [ADR-0006](adr/0006-serverless-aws.md).

```
                    ┌──────────────────────────────────┐
   Verifier apps ──►│ CloudFront + WAF                 │
                    │ API Gateway (HTTP API)           │
                    │  ├─ JWT authorizer (Cognito)     │
                    │  └─ App Attest authorizer (λ)    │
                    └──────────────┬───────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
  ┌───────────┐            ┌──────────────┐          ┌───────────────┐
  │ λ ingest  │            │ λ tenant-api │          │ λ dashboard   │
  │ (batch)   │            │ (CRUD)       │          │ (aggregates)  │
  └─────┬─────┘            └──────┬───────┘          └───────┬───────┘
        │                         │                          │
        └───────────┬─────────────┴──────────────────────────┘
                    ▼
          ┌────────────────────┐        ┌──────────────────────┐
          │ DynamoDB           │───────►│ DDB Streams          │
          │ single table       │        │  → EventBridge       │
          │ on-demand          │        └──────┬───────────────┘
          └────────────────────┘               │
                    ▲                  ┌───────┴────────┬─────────────┐
                    │                  ▼                ▼             ▼
          ┌─────────┴────────┐   ┌───────────┐   ┌────────────┐  ┌─────────┐
          │ AppConfig        │   │ Firehose  │   │ SQS +λ     │  │ SNS     │
          │ · jurisdictions  │   │ → S3      │   │ webhooks   │  │ alerts  │
          │ · feature flags  │   │ (Parquet) │   │ (per-tenant│  └─────────┘
          │ · kill switches  │   │ → Athena  │   │  retry/DLQ)│
          └──────────────────┘   └───────────┘   └────────────┘
```

**Key choices:**

- **DynamoDB single-table**, on-demand billing. Access patterns are known and
  narrow; on-demand absorbs the Saturday spike with no capacity planning and
  costs almost nothing Monday–Thursday. Schema in [`DATA_MODEL.md`](DATA_MODEL.md).
- **Batch ingest.** The client drains its outbox in batches of up to 50, so a
  busy door is a handful of requests per minute, not one per tap. Idempotent on
  client-generated ULID via conditional writes, so retries are free.
- **AppConfig for the supported-jurisdiction list.** Apple adds states on their
  own schedule. Hardcoding the list means an App Store release every time a
  state ships — unacceptable. Hot-reloaded config, cached locally with a TTL so
  it works offline. This is the highest-value flag in the system.
- **Scheduled provisioned concurrency** on the ingest and auth Lambdas,
  Thu–Sat 8pm–3am local per region. Kills cold-start latency at the door
  without paying for it all week.
- **EventBridge as the extension point.** Every new feature (banned-patron
  lists, occupancy counting, POS integration, compliance reporting) subscribes
  to the event stream instead of modifying the ingest path.

### 3.3 Multi-tenancy

Venues are tenants; chains are organizations owning many venues.

```
Organization (chain)
└── Venue (physical location, timezone, local ordinances)
    ├── StaffMember (roles: owner, manager, door)
    ├── Device (enrolled iPhone, App Attest key, attestation state)
    └── Shift (staff × device × venue × time window)
```

Isolation strategy, in order of increasing rigor as the business grows:

1. **v1 — pooled with enforced partition prefixes.** Every DDB key starts
   `ORG#{orgId}`. A shared IAM policy uses `dynamodb:LeadingKeys` conditions so
   even a code bug cannot read across tenants. Cheapest, scales to thousands of
   venues.
2. **Growth — per-tenant KMS keys** for any tenant that opts into a retention
   tier, giving cryptographic separation and per-tenant crypto-shredding.
3. **Enterprise — silo option** (dedicated table/account) for a chain that
   contractually demands it. The repository interfaces make this a
   configuration change, not a rewrite.

**Auth is shift-based, not user-based** — an important detail. Door staff share
devices and rotate. Modeling "who was on the door at 12:40am" as a *shift*
rather than a login session is what makes the audit trail hold up. A device
holds a long-lived, hardware-bound credential; a human claims a shift on it
with a short PIN. See [`API.md`](API.md#auth-model).

---

## 4. Primary flow: a tap at the door

```
 1. Attendant opens TapID. Shift already active. Screen shows one big button.
 2. Tap "Check ID" → Flutter calls rail.beginVerification()
 3. Swift builds a Display-Only request for the MINIMUM element set:
       age_at_least_21, portrait, given_name, family_name
    (Deliberately NOT full DOB, NOT address, NOT document number.
     Minimal disclosure is both a privacy win and a smaller compliance surface.)
 4. Apple's native sheet appears. Patron taps their iPhone. Face ID/consent
    happens on the PATRON's device — we never see their biometric.
 5. OS validates the issuer signature in the Secure Element.
 6. Apple renders portrait + name + "Over 21: Yes" for the attendant to compare
    against the human in front of them.
 7. Attendant makes the call: Approve / Decline. This is a HUMAN decision and
    is recorded as such — TapID does not perform face matching. (ADR-0003)
 8. Sheet dismisses. Swift emits the redacted DTO. All PII is now gone from
    process memory.
 9. Outcome → encrypted local outbox → batched sync → DynamoDB → event stream.
10. Screen returns to the one big button in under 500ms.
```

**Design targets** (from the door's perspective, not the server's):

| Metric | Target | Why |
|---|---|---|
| Tap-to-decision | < 3s p95 | A line forms fast. This is the whole UX. |
| Screen-ready after decision | < 500ms p95 | Throughput at the door. |
| Offline capability | 100% of verifications | Cryptographic validation is local. |
| Outbox durability | Survives force-quit, reboot, 72h offline | Audit trail integrity. |
| Sync latency (online) | < 60s p95 | Dashboard freshness only — not on the critical path. |

Note what is *not* on the critical path: the network. That is deliberate.

### Failure modes and what the attendant sees

| Condition | Behavior |
|---|---|
| Patron's state unsupported | Clear "This state's digital ID isn't supported yet — check physical ID" + logged as `unsupportedIssuer` so we can quantify demand per state |
| Patron has no digital ID | Logged as manual fallback; still creates an audit record |
| Read fails / patron pulls phone away | Retry prompt, `readFailed` recorded, no penalty |
| Credential expired | Surfaced explicitly — an expired mDL is a decline, not an error |
| Backend unreachable | Invisible to the attendant. Queue depth shown in settings only. |
| Outbox near capacity (>10k) | Non-blocking banner to manager role, not door staff |

---

## 5. Scalability

Scale dimensions, and the design's answer to each:

| Dimension | v1 headroom | First thing to break | Mitigation already in design |
|---|---|---|---|
| Taps/sec | ~5k/s (DDB on-demand) | Per-partition write limit if one venue is hot | Key includes venue + time bucket, so writes spread |
| Venues | Tens of thousands | Dashboard aggregate queries | Pre-computed rollups via Streams, never scan |
| Devices | ~100k | App Attest verification cost per request | Assertion cached per device-session, re-verified on rotation |
| Events retained | Unbounded in S3 | Athena query cost | Parquet + date partitioning; DDB holds a 90-day hot window with TTL |
| Regions | 1 (us-east-1) | Latency for west-coast venues | API is stateless; DDB Global Tables + latency routing when needed |

The system is stateless at the API tier and event-driven behind it, so the
scaling path is "add subscribers," not "rewrite the ingest."

**Cost intuition.** Because billing is per-request and traffic is concentrated,
cost tracks actual verifications closely rather than provisioned peak. A venue
doing 500 checks/night, 4 nights/week, sits in the low single-digit dollars per
month of infrastructure — the unit economics work at small scale, which matters
for landing the first venues.

---

## 6. Repository layout

```
tapid/
├── docs/
│   ├── ARCHITECTURE.md      ← this file
│   ├── DATA_MODEL.md        DynamoDB single-table design, access patterns
│   ├── API.md               endpoints, auth model, error contract
│   ├── COMPLIANCE.md        Apple terms, BIPA/CCPA, state alcohol law
│   ├── THREAT_MODEL.md      attacker-by-attacker analysis
│   ├── ROADMAP.md           phasing, and the Apple entitlement critical path
│   └── adr/                 decision records
├── apps/verifier_app/       Flutter app + native iOS verification module
├── services/api/            Lambda handlers (TypeScript)
├── infra/terraform/         Terraform (HCL)
└── scripts/                 dev tooling
```

---

## 7. What is deliberately out of scope for v1

Each of these is a real product opportunity, and each is deferred with a reason.
Listing them is part of the design — it documents where the seams need to be.

- **Android / Google Wallet / ISO 18013-5 rails.** Scoped out per your v1
  decision. The `VerificationRail` interface is the seam where they attach; it
  costs nothing today and saves a refactor later. See
  [ADR-0007](adr/0007-single-rail-with-seam.md) for why the interface exists
  even with one implementation.
- **PDF417 barcode scanning** for physical licenses. Highest-demand follow-on,
  since it covers 100% of patrons rather than ~15%.
- **Automated face matching.** Legally hazardous (BIPA), and Display-Only
  forbids it. The human stays in the loop by design, not by limitation.
- **PII retention tiers**, banned-patron lists, occupancy counting, POS
  integration. All are EventBridge subscribers.

---

## 8. Known risks

| Risk | Severity | Standing |
|---|---|---|
| Apple denies or slow-walks the entitlement | **Critical — blocks launch** | Mitigated for *development* by mock-rail parity, but not for launch. Start the application immediately; it is the critical path. See [`ROADMAP.md`](ROADMAP.md#critical-path). |
| Only ~15 states + iPhone-only patrons | High — limits coverage | Every unsupported read is logged, turning the gap into a quantified roadmap for the barcode rail |
| Venue liability expectations exceed what an attestation proves | High | [`COMPLIANCE.md`](COMPLIANCE.md) draws the line explicitly; product copy must not overclaim |
| Apple changes ProximityReader API or terms | Medium | Rail isolation confines the blast radius to one Swift file |
| Bouncers reject a slower flow than glancing at a plastic card | Medium — adoption risk | The <3s target is a product requirement, not an aspiration. Validate with real door staff early. |

The last one is worth emphasizing: the competition is not another app, it is a
two-second glance at a plastic card. Anything that makes the door slower loses,
regardless of how good the cryptography is.
