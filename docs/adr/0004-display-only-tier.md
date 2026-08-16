# ADR-0004 — Target Apple's Display-Only tier for v1

**Status:** Accepted · **Date:** 2026-07-29

## Context

Apple's ID Verifier offers two entitlements:

| | Display Only | Data Transfer |
|---|---|---|
| Entitlement | `com.apple.developer.proximity-reader.identity.display` | `com.apple.developer.proximity-reader.identity.read` |
| Data reaches our code | No — Apple renders it on screen | Yes — returned to the app |
| Retention | Prohibited | Contractually constrained |
| Vetting | Lower barrier | Higher; separate agreement |

The original concept — "immediately get the photo of the person along with name,
birthday, and other relevant data" — describes Data Transfer. So this decision is
a deliberate narrowing of the initial ask, and worth being explicit about.

## Decision

Target **Display Only** for v1. Apple renders the portrait and identity fields;
the attendant reads them off the screen and makes the call. Our app receives only
the redacted outcome.

## Rationale

**It is the faster approval path**, and the entitlement is the critical path for
the entire project ([`ROADMAP.md`](../ROADMAP.md#critical-path)). Lower vetting
burden means a shorter time to a working product and a better chance of approval
at all — for a pre-revenue company with no verification track record, asking for
the higher tier invites a harder review.

**It makes zero-retention structural rather than procedural.** Under Data
Transfer, "we don't store PII" is a promise enforced by code review and
discipline. Under Display Only, the data largely never enters our process, so the
promise is enforced by Apple's own architecture. That is a materially stronger
guarantee, and it is the foundation
[ADR-0003](0003-zero-retention.md) rests on.

**The functional loss is small for the actual job.** What the door needs is: is
this person over 21, and is this their ID? A human comparing a face to a portrait
on screen answers both. Having the portrait bytes in our process adds no value to
that decision — it only adds liability, since processing a portrait for identity
matching is what risks pulling us into BIPA scope
([`COMPLIANCE.md`](../COMPLIANCE.md#2-biometric-privacy-law--why-we-dont-do-face-matching)).

**Minimum-element requests still apply.** Even within Display Only we request
only `age_at_least_21`, portrait, given name, family name — not full date of
birth, not address, not document number. Note that `age_at_least_21` is
categorically better than requesting a DOB and computing age ourselves: the
issuer asserts the predicate directly, so there is no birthdate to disclose or
mishandle at all.

## Consequences

**Good**
- Faster, more likely entitlement approval
- Zero-retention enforced by Apple's architecture, not our vigilance
- BIPA exposure minimized
- Simpler client: no PII lifecycle to manage in memory

**Bad**
- **UI is Apple's, not ours.** We cannot restyle the verification sheet,
  add venue branding, or adjust the layout for a dark, fast-moving door.
- No programmatic access to identity fields, so no automated cross-checks
- Any future feature needing patron identity requires a tier upgrade and a new
  review cycle
- We depend on Apple's sheet being legible in real door conditions — something
  only the Phase 1 field test can validate

## Upgrade path to Data Transfer

Should a genuine requirement emerge — a chain demanding automated logging of
identity fields, or a jurisdiction whose statute requires recording specific data
— the upgrade is contained:

1. Apply for the `identity.read` entitlement (separate Apple agreement)
2. Implement a second request path in `AppleWalletRail.swift`
3. **Expand the platform-channel DTO** — the deliberate chokepoint. Widening it
   requires a new ADR and a compliance review by design ([ADR-0001](0001-flutter-plus-native-tap.md)).
4. Add PII-bearing storage, encryption, and retention policy — the expensive part,
   and the reason [ADR-0003](0003-zero-retention.md) exists

Steps 1–2 are days of work. Steps 3–4 are a compliance program. The architecture
makes that cost visible up front rather than letting it accrue by accident.
