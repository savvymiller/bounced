# Roadmap & Phasing

**Status:** Design v1

---

## Critical path

**The Apple entitlement is the long pole, and it is not an engineering task.**

Both prior prototypes in this workspace (`BouncerCheck/`, `id-check/`) reached a
working app shell and then stalled at a stubbed verifier — `WalletVerifierService.swift`
literally throws "Add your Apple Verifier entitlement here." That is the failure
mode to avoid repeating, and it was a sequencing failure, not a technical one.

```
Week 0  ──► Form business entity ──► Apple Developer Program (org, D-U-N-S)
              │
              ├──► Apply for ID Verifier / Display-Only entitlement
              │      ⏳ Apple vetting: weeks to months, outcome not guaranteed
              │
              └──► ENGINEERING PROCEEDS IN PARALLEL against the mock rail
                     (everything except AppleWalletRail.swift is buildable today)
```

Two implications worth acting on immediately:

1. **Start the entitlement application before writing significant code.** Its
   lead time exceeds the time to build the rest of v1. Engineering is not the
   bottleneck; Apple's review queue is.
2. **Build against the mock rail from day one.** [ADR-0002](adr/0002-mock-rail-parity.md)
   makes the mock a contract-tested first-class implementation, so ~90% of the
   product is complete and demoable while the entitlement is pending. When
   approval lands, one Swift file gets implemented.

If Apple denies the entitlement, the mock-rail investment is still not wasted —
it is the harness the ISO 18013-5 or barcode rail would plug into instead.

---

## Phase 0 — Foundation (parallel with Apple application)

Goal: a demoable app and a real backend, with the mock rail.

- Repo, CI, Terraform bootstrap; DynamoDB table + IaC for the ingest path
- Flutter shell: auth, shift claim, door screen, history, settings
- Native module scaffolding + Pigeon contract + `MockRail.swift`
- Encrypted outbox (Drift + SQLCipher) and the sync loop
- App Attest enrollment and the Lambda authorizer
- Contract test suite both rails must satisfy

**Exit criteria:** a full end-to-end verification — mock tap → local queue →
batched sync → DynamoDB → dashboard rollup — running offline and online, with
the tap being the only simulated element.

## Phase 1 — Real rail (gated on Apple approval)

- Implement `AppleWalletRail.swift` against the actual ProximityReader API
  (pin exact symbol names to the SDK — do not trust remembered signatures)
- Validate the redaction boundary against real returned data
- Device capability gating (iPhone XS+, iOS 17+); graceful messaging otherwise
- On-device latency tuning against the <3s p95 target
- Field test at one friendly venue on a real Saturday night

**Exit criteria:** real taps at a real door, meeting the latency targets, with
door staff who were not involved in building it.

## Phase 2 — First paying venues

- Venue web dashboard (rollups, shift history, staff management)
- Async compliance export (Athena → presigned S3)
- Device fleet management and revocation
- Scheduled provisioned concurrency for weekend peaks
- Alerting, runbooks, on-call — a Saturday-night outage is a lost customer
- Onboarding: signage, staff training material, terms + DPA

**Exit criteria:** venues paying and renewing, with a support process that
survives a Friday night.

## Phase 3 — Coverage expansion

Driven by data, not guesses: the `unsupportedIssuer` rollup counter from
[`DATA_MODEL.md`](DATA_MODEL.md) quantifies exactly how many patrons v1 turns
away, and from which states.

- **PDF417 barcode rail** for physical licenses — likely the single highest-value
  addition, since it moves coverage from ~15% of patrons to ~100%
- **Google Wallet / ISO 18013-5 rails** for Android holders
- Each attaches at the `VerificationRail` seam ([ADR-0007](adr/0007-single-rail-with-seam.md))

## Phase 4 — Platform

- Occupancy counting, POS/ticketing integrations, chain-level analytics
- Multi-region, SOC 2 Type II
- All as EventBridge subscribers — the ingest path should not change

---

## Sequencing rationale

The ordering is driven by one question: *what is most likely to kill this
project?*

| Rank | Risk | Addressed in |
|---|---|---|
| 1 | Apple never grants the entitlement | Week 0 — start immediately, and keep the mock rail viable as a hedge |
| 2 | Bouncers won't use it because it's slower than a glance at a card | Phase 1 field test — with real staff, on a real busy night |
| 3 | Coverage too low to be worth paying for | Phase 3, prioritized by measured `unsupportedIssuer` data |
| 4 | Compliance/legal blocks a launch state | [`COMPLIANCE.md`](COMPLIANCE.md) checklist, per state, before that state |
| 5 | Doesn't scale | Already designed for; deliberately last |

Scale is genuinely last. The architecture in [`ARCHITECTURE.md`](ARCHITECTURE.md)
is built to absorb growth so that scaling is not a rewrite — but a system that
scales beautifully and that no bouncer will use is worth nothing. Risks 1 and 2
deserve disproportionate attention early, and both are validated by activities
outside the code: an application to Apple, and a night at a real door.
