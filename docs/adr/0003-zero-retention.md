# ADR-0003 — Zero retention of patron identity data

**Status:** Accepted · **Date:** 2026-07-29

## Context

A verification returns a portrait, name, and age assertion. The obvious product
instinct is to store it: incident lookback, banned-patron lists, repeat-visit
analytics, dispute resolution. Every one of those is a real feature a venue would
pay for.

Storing it also creates the largest liability in the business. Note that
established ID-scanning vendors have converged on storing nothing — that is a
signal about where the risk actually sits.

## Decision

**No patron identity data is persisted or transmitted anywhere.** Not encrypted,
not with a TTL, not opt-in per venue.

The backend receives only:

```jsonc
{
  "eventId": "01H8XQVK...",
  "venueId": "v_01H8X", "deviceId": "dev_01H8B", "staffId": "stf_01H8D",
  "railResult": "approved",
  "ageAtLeast21": true,
  "humanDecision": "allowed",
  "issuingJurisdiction": "CA",      // state only — never a document number
  "occurredAt": "2026-07-29T04:12:33.412Z"
}
```

Enforced at three layers, so no single lapse defeats it:

1. **Platform channel** — the Pigeon DTO has no PII fields ([ADR-0001](0001-flutter-plus-native-tap.md))
2. **Schema** — no PII column exists in DynamoDB ([`DATA_MODEL.md`](../DATA_MODEL.md))
3. **Apple's tier** — Display Only means the OS renders the data and our process
   largely never holds it ([ADR-0004](0004-display-only-tier.md))

## Rationale

**Apple requires it.** Display-Only terms prohibit retaining or transmitting
presented ID data. Violation risks entitlement revocation, which is not a fine —
it is the product ceasing to function. This alone is dispositive.

**It removes the worst legal exposure.** Processing a portrait for identity
purposes risks creating a "biometric identifier" under Illinois BIPA, which
carries a private right of action and per-violation statutory damages. Storing
names and DOBs for thousands of venues would make TapID a processor of sensitive
personal information under CCPA/CPRA and its state analogues, with DSAR handling,
retention schedules, and breach notification in every jurisdiction. See
[`COMPLIANCE.md`](../COMPLIANCE.md).

**It makes a breach nearly uninteresting.** The worst case discloses that a check
occurred at a venue at a time — not who was checked. Compare the alternative: a
breach of portraits, names, and dates of birth for millions of bar patrons is a
company-ending event.

**It is a sales asset, not just a constraint.** "We cannot leak your patrons'
data because we never receive it" is a strong, verifiable claim, and it makes
long S3 retention for compliance exports a low-risk proposition.

## Consequences

**Good**
- Satisfies Apple's terms structurally
- Keeps BIPA and most CCPA duties out of scope
- Minimal breach blast radius; 7-year archive is safe to keep
- Simpler operations: no DSAR tooling, no per-tenant deletion pipelines, no
  encryption-key lifecycle for patron data

**Bad — and these are real product costs**
- **No banned-patron lists.** A venue that wants to keep a specific person out
  cannot do it through TapID. This will be requested, and the answer is no on the
  Apple rail.
- **No repeat-visit or patron analytics.** A whole category of upsell is closed.
- **Weaker dispute resolution.** We can prove a valid check happened and who
  performed it, but not who was presented.
- **Reversal is expensive.** Adding retention later means schema changes, a
  compliance program, likely a Data Transfer entitlement, and re-papering every
  venue contract.

The last point is why this is decided now rather than deferred: the cheap moment
to choose zero-retention is before any customer depends on the alternative.

**On the rejected alternative:** per-venue configurable retention looks more
flexible on a roadmap, but it would mean building the full compliance apparatus
on day one for a feature no pilot customer has asked for — and it likely violates
Apple's Display-Only terms regardless, making it unavailable at exactly the tier
we are launching on.

## Revisiting this

Legitimate future paths, each requiring independent legal review and probably a
Data Transfer entitlement ([ADR-0004](0004-display-only-tier.md)):

- **Salted one-way hashes** for repeat detection without identity — subtler than
  it sounds, since a hash of a document number is likely still personal data
- **On-device-only** banned lists, where a template never leaves the venue's phone
- **Explicit patron consent** flows for opted-in loyalty features

None are in v1 scope. Do not promise them to a venue before counsel signs off.
