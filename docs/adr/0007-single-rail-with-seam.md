# ADR-0007 — One rail implementation, but keep the interface seam

**Status:** Accepted · **Date:** 2026-07-29

## Context

v1 scope is Apple Wallet only. The alternatives considered and set aside were
Google Wallet ID Pass, generic ISO 18013-5 mDL over NFC/BLE, and PDF417 barcode
scanning of physical licenses.

A fair objection to defining a `VerificationRail` interface with exactly one
implementation: that is speculative generality, and YAGNI says don't.

## Decision

Define the `VerificationRail` interface, and ship exactly one production
implementation (`AppleWalletRail`) plus one test implementation (`MockRail`).

Do **not** build stub or partial implementations of the other rails.

## Rationale

The interface costs essentially nothing here because **it already has two
implementations on day one.** `MockRail` is not hypothetical — it is required
infrastructure for the entire pre-entitlement development period
([ADR-0002](0002-mock-rail-parity.md)). The moment a second implementation exists,
the abstraction is validated by use rather than by speculation, and this stops
being speculative generality at all.

The interface is also the natural place to hang things that are needed regardless:
capability detection (is this device an iPhone XS+ on iOS 17+?), the redaction
boundary, latency instrumentation, and the shared outcome taxonomy. Without a rail
abstraction those concerns get scattered through the door-screen code.

And the outcome taxonomy is genuinely rail-independent. `unsupportedIssuer`,
`readFailed`, `expired`, `cancelled` are facts about *any* age-verification
mechanism, not artifacts of Apple's API. Designing them once, at the interface,
is what lets [`DATA_MODEL.md`](../DATA_MODEL.md) record `unsupportedIssuer` counts
that stay meaningful when a second rail arrives.

**What makes this different from speculative generality** is that we are not
guessing at the shape of future rails. We are defining the shape of the *outcome*,
which is dictated by what the door and the audit trail need — and that is already
fully known.

## Consequences

**Good**
- Mock/real parity, and a contract suite that becomes the acceptance criteria for
  any future rail
- Capability detection and redaction live in one obvious place
- A future rail is additive: implement the interface, pass the contract suite,
  register it. No changes to the door screen, outbox, sync, or backend.
- Apple API churn is confined to one Swift file

**Bad**
- One extra layer of indirection to read through when debugging the tap flow
- Mild risk of the interface being shaped too tightly around Apple's model —
  Apple's flow is a single OS-owned modal sheet, whereas ISO 18013-5 involves
  explicit device engagement and session establishment, which may not fit a
  single `beginVerification()` call cleanly

**Mitigation for the shaping risk:** keep the interface deliberately coarse — one
async call in, one outcome out, plus a capability query. A coarse interface is far
easier to widen for a rail with a different interaction model than a fine-grained
one modeled on Apple's specific session lifecycle. Resist the temptation to
expose Apple's intermediate states.

## What is explicitly not being built

No `GoogleWalletRail.swift`, no `Iso18013NfcRail.swift`, no `Pdf417Rail.swift` —
not even as stubs. Empty stubs are worse than nothing: they imply support that
does not exist, they show up in code search, and they rot.

The roadmap for these lives in [`ROADMAP.md`](../ROADMAP.md#phase-3--coverage-expansion),
prioritized by measured `unsupportedIssuer` data rather than by guesswork about
which states matter.
