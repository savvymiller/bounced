# ADR-0001 — Flutter shell with a native iOS verification module

**Status:** Accepted · **Date:** 2026-07-29

## Context

The stated plan is a Flutter mobile app. Apple's ID Verifier lives in the
**ProximityReader** framework and presents its own native, Apple-owned UI sheet
during the tap. Flutter cannot render or reimplement that sheet, and there is no
first-party Flutter plugin for it.

So a pure-Flutter implementation of the tap is not possible — the question is
whether Flutter still earns its place in the rest of the app.

## Decision

Keep Flutter for the app, and implement the verification rail as a native Swift
module behind a Pigeon-generated platform channel.

The channel's outcome DTO is restricted to non-PII fields only:

```dart
class VerificationOutcome {
  String eventId;
  RailResult result;
  bool? ageAtLeast21;
  String? issuingJurisdiction;   // "CA" — state only
  DateTime occurredAt;
  Duration readLatency;
  // no name, no DOB, no portrait, no document identifier
}
```

## Rationale

The tap screen is roughly 10% of the application. Auth, shift claiming, venue
settings, history, incident notes, staff roster, the offline outbox and its UI,
and eventually an Android build for non-tap features are all ordinary UI work
where Flutter's single codebase is a real advantage.

Rewriting that 90% in Swift to avoid one platform channel would be the wrong
trade. A well-defined channel for a native capability is a normal, well-trodden
Flutter pattern.

**The unexpected benefit:** the channel boundary turns out to be the ideal place
to enforce zero-retention. Because the generated DTO has no PII fields, patron
data physically cannot cross into Dart — not by oversight, not by a careless
`print()` in the Flutter layer. A privacy property that would otherwise depend on
developer discipline becomes a property of the type system.

Pigeon over hand-written `MethodChannel` code specifically because it generates
both sides from one schema, so the DTO restriction is mechanically enforced
rather than duplicated by hand.

## Consequences

**Good**
- One codebase for the large majority of the product
- PII containment is structural, enforced by codegen
- The rail is isolated to a small set of Swift files, so an Apple API change has
  a tightly bounded blast radius

**Bad**
- Two languages, two toolchains, and a codegen step in the build
- The verification flow cannot be tested in the Flutter widget-test harness
  alone; it needs integration tests on a physical device
- Developers need Xcode and a real iPhone (Simulator cannot do ProximityReader)

**Guardrails**
- CI fails if the outcome DTO gains a field without an ADR reference in the
  commit message — see [`THREAT_MODEL.md`](../THREAT_MODEL.md#t4-pii-leakage-via-client-logs)
- A dependency allowlist forbids analytics/crash SDKs inside the verification
  module

## Alternatives considered

**Full native SwiftUI app.** Both prior prototypes took this path
(`BouncerCheck/`, `id-check/`) and neither reached the entitlement, so there is
no evidence it was faster in practice. It also forecloses Android entirely, which
matters for the Google Wallet and barcode rails on the roadmap.

**React Native.** Same native-module requirement, weaker typed-codegen story than
Pigeon for the boundary we most care about locking down.

**Flutter with a hand-written MethodChannel.** Rejected: untyped maps across the
boundary is precisely where a stray PII field would slip through unnoticed.
