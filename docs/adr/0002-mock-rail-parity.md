# ADR-0002 — Mock rail as a contract-tested first-class implementation

**Status:** Accepted · **Date:** 2026-07-29

## Context

Apple's ID Verifier entitlement requires business vetting and an approval process
measured in weeks to months, with no guaranteed outcome. Until it is granted, the
real tap cannot run at all — not even on a physical device.

There is direct evidence in this workspace of what happens if this is not planned
for. Two prior prototypes each built an app shell and stopped:

```swift
// BouncerCheck/Services/WalletVerifierService.swift:30
throw NSError(..., "Add your Apple Verifier entitlement and reader session logic here.")
```

Both stalled at the same wall. That was a sequencing failure, not a technical one.

## Decision

Treat `MockRail` as a **first-class, contract-tested implementation** of
`VerificationRail`, not as throwaway scaffolding.

Both rails must pass an identical contract test suite covering every outcome:
`approved`, `declined`, `expired`, `unsupportedIssuer`, `readFailed`,
`cancelled`, plus latency distributions and concurrent-invocation behavior.

The mock is driven by a fixture file so QA and demos can script specific
scenarios (an underage patron, an expired credential, an unsupported state, a
read that times out) deterministically and repeatably.

Availability is controlled by the `mockRailAllowed` server flag, defaulting
**off** in production builds and enforced by a release-build compile guard —
belt and braces, because a mock rail reachable in production would let a venue
fabricate approvals.

## Rationale

This decouples ~90% of the product from an external dependency we do not control.
Everything except one Swift file — auth, shifts, the outbox, sync, idempotency,
the dashboard, rollups, tenant isolation — is buildable, testable, and demoable
today.

The contract suite is what makes the decoupling real rather than nominal. Without
it, "we'll swap in the real rail later" means discovering a pile of unhandled
error paths on the day the entitlement lands. With it, the real rail has a
precise definition of done, and the failure paths are already exercised
throughout the app.

It also hedges the worst case: if Apple denies the entitlement, the contract suite
and everything above it is exactly the harness an ISO 18013-5 or PDF417 barcode
rail would plug into instead. The investment survives the risk that motivated it.

## Consequences

**Good**
- Engineering proceeds fully in parallel with Apple's review queue
- Failure paths get real coverage, rather than being an afterthought
- Deterministic demos without a supported physical ID on hand
- Contract suite becomes the acceptance criteria for every future rail

**Bad**
- Ongoing cost to keep two implementations in sync
- Risk of over-trusting the mock: it cannot model real NFC read failures,
  antenna placement, patron-side Face ID timing, or Apple's actual sheet latency
- The mock's existence must be rigorously gated out of production

**Mitigation for the over-trust risk:** Phase 1 explicitly includes a field test
at a real venue on a real Saturday night before any paying customer. Mock parity
proves the software is correct; only a real door proves the product works.
