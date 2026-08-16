# Threat Model

**Status:** Design v1

TapID's product value is that its records are *believable* — a venue shows them
to a liquor board to prove it checked IDs properly. So the primary threat is not
data theft (we hold almost no data by design); it is **fabrication of records**.

Attackers are ordered by how much they actually threaten the business.

---

## T1 — Forged attestations
**Attacker:** a venue owner facing a compliance penalty, or an employee covering
for letting a minor in. **This is the most important threat in the system.**

Motive is strong and the payoff is direct: fabricate a clean record of a check
that never happened, or retroactively "prove" a refused entry. If this is
possible, every record we hold is worthless and the product has no value.

**Defenses:**

- **App Attest assertion over every request body.** Proves the request came from
  a genuine, unmodified TapID binary on genuine Apple hardware. A curl script
  with valid credentials cannot produce one.
- **Monotonic counter** per device. A replayed assertion arrives with a
  non-increasing counter and is rejected (`attestation_counter_replay`).
- **Server-side `receivedAt` + `clockSkewMs`.** The device clock is under the
  venue's control, so a backdated event is detectable. Legitimate offline queuing
  produces a large *positive* delay with a consistent counter sequence;
  tampering tends to produce inconsistencies between the two.
- **Rollups computed server-side** from the event stream, so a venue cannot edit
  its own aggregate numbers.
- **No event mutation or deletion API exists.** Records are append-only.
  Corrections are new events referencing the original, never edits.

**Residual risk:** a jailbroken device can potentially defeat App Attest. Accepted
for v1; mitigated by flagging devices whose attestation receipt fails periodic
re-validation with Apple, and by anomaly detection on rollups (a venue with a
99.9% approval rate and zero read failures is statistically implausible).

---

## T2 — Patron presenting a credential that is not theirs
**Attacker:** an underage patron using an older sibling's phone.

Notably, this is *harder* than with a plastic card: presenting an Apple Wallet ID
requires Face ID or a passcode on the patron's own device at the moment of
presentation. A borrowed phone fails unless the owner also shares their passcode.

**Defenses:** patron-side biometric consent (enforced by iOS, not by us); the
portrait is displayed for human comparison; the attendant's decision is recorded
separately from the credential's validity, so `ageAtLeast21: true` +
`humanDecision: refused` is a legible, expected outcome.

**Residual risk:** face-match quality depends on a human in a dark room. This is
the same limitation as physical ID checking, and TapID does not claim to solve
it — see [`COMPLIANCE.md`](COMPLIANCE.md#what-tapid-does-not-prove). Automated
matching is deliberately excluded (BIPA exposure, and prohibited under
Display-Only terms).

---

## T3 — Lost or stolen verifier device
**Attacker:** opportunist with a device taken from a bar.

A door iPhone in a loud, dark, crowded room is a frequently-lost object. This is
an operational certainty, not an edge case.

**Defenses:** no PII on the device at rest (there is none to take — see
[ADR-0003](adr/0003-zero-retention.md)); outbox encrypted with SQLCipher keyed
from the Keychain; credentials non-exportable and
`AfterFirstUnlockThisDeviceOnly`; `POST /devices/{id}:revoke` invalidates
immediately; shift auto-close bounds the window of misattributed events.

**Residual risk:** unsynced queued events are lost if the device is wiped before
draining. Accepted — they are records of checks, not the checks themselves.

---

## T4 — PII leakage via client logs
**Attacker:** none required. This is an accident waiting to happen, and the one
most likely to actually occur.

A developer adds `print(response)` while debugging the tap flow, and a patron's
name and DOB land in a crash report, an analytics SDK, or CloudWatch — creating
exactly the BIPA/CCPA exposure the architecture was built to avoid.

**Defenses:**

- **The platform-channel DTO has no PII fields at all.** PII cannot cross the
  Swift→Dart boundary because there is no field to carry it. This is structural,
  not disciplinary.
- Apple's Display-Only tier means the sensitive data is largely rendered by the
  OS and never enters our process in the first place.
- PII-bearing Swift values are confined to the narrowest possible scope and
  explicitly zeroed on sheet dismissal.
- **CI check** fails the build if the outcome DTO gains a field without an ADR
  reference in the commit message.
- No third-party analytics or crash SDK is permitted in the verification module —
  enforced by a dependency allowlist.
- Structured logging only, with an allowlisted key set.

**Residual risk:** low, and it is the residual risk I would most want to keep
verifying — a single careless log line undoes the whole posture.

---

## T5 — Cross-tenant data access
**Attacker:** a competitor venue, or a curious chain manager.

**Defenses:** every key prefixed `ORG#`/`VENUE#`; IAM `dynamodb:LeadingKeys`
conditions so isolation is enforced by AWS rather than by application code — a
query bug fails closed; tenant ID always derived from the validated token, never
from a request parameter or body; contract tests attempt cross-tenant reads and
must receive `AccessDenied`.

**Residual risk:** pooled storage means a sufficiently deep infrastructure
compromise crosses tenants. The per-tenant-KMS and silo tiers in
[`ARCHITECTURE.md`](ARCHITECTURE.md#33-multi-tenancy) exist for customers who
need that eliminated.

---

## T6 — Denial of service at the door
**Attacker:** usually not an attacker at all — an AWS outage, a bad deploy, or a
dead cell signal in a basement.

If TapID goes down and the door stops moving, the venue stops using TapID
permanently. Availability of the *door* matters far more than availability of the
*backend*.

**Defenses:** verification is fully local — issuer-signature validation needs no
network, so the door keeps working through a total backend outage; events queue
in the outbox and drain later; the app shows no error to door staff for sync
failures (queue depth is a manager-role concern); config cached with a TTL so an
AppConfig outage cannot brick the app; CloudFront + WAF absorb volumetric
attacks before Lambda.

**Design consequence:** the network is deliberately kept off the critical path.
This is the single most important availability decision in the system.

---

## T7 — Malicious or compromised patron device
**Attacker:** a patron with a modified phone attempting to present a forged
credential.

**Defense:** we do not validate the credential — the iOS Secure Element does,
against the issuing state's signature, before anything is displayed. Forging
requires the state's signing key. This threat is essentially outsourced to Apple
and the issuing authority, which is the correct place for it.

**Residual risk:** a compromise of a state's mDL signing infrastructure. Out of
scope; would be a national-scale incident.

---

## Trust boundaries

```
┌─ Patron device ─────────┐   Untrusted. Validated by iOS Secure Element.
└─────────────────────────┘

┌─ Verifier device ───────┐   Semi-trusted. Attested via App Attest.
│  Flutter  │  Swift rail │   ← internal boundary: PII stops at the DTO
└─────────────────────────┘

┌─ AWS backend ───────────┐   Trusted. Tenant-isolated at the IAM layer.
└─────────────────────────┘

┌─ Venue dashboard user ──┐   Semi-trusted. Cognito + MFA, role-scoped,
└─────────────────────────┘   read-only over append-only records.
```

The "semi-trusted verifier device" designation is the crux: the venue operates
the device and has a motive to lie with it, so the backend must not accept its
claims on faith. That is what T1's defenses are for.

---

## Ongoing verification

| Control | Cadence |
|---|---|
| DTO field-addition CI check | every commit |
| Cross-tenant contract tests | every deploy |
| Dependency allowlist audit (verification module) | every dependency change |
| App Attest receipt re-validation with Apple | weekly, per device |
| Rollup anomaly review (implausible approval rates) | weekly |
| Full threat model review | quarterly, and on any new rail |
