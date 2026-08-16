# Compliance & Legal Surface

**Status:** Design v1

> **This document is engineering analysis, not legal advice.** Age verification
> for alcohol service is regulated per-state and sometimes per-city, and
> biometric/identity law is actively changing. Retain counsel in your launch
> states before the first paying venue. Several items below are flagged as
> requiring a lawyer's answer, not an engineer's.

The reason this document exists at the design stage: the retention decision
([ADR-0003](adr/0003-zero-retention.md)) is nearly irreversible once customers
depend on it, and it is driven entirely by the law rather than by engineering
preference.

---

## 1. Apple's terms are the binding constraint

Apple's ID Verifier program is contractual, not merely technical. The
Display-Only tier's requirements are stricter than most privacy statutes:

| Requirement | How the architecture satisfies it |
|---|---|
| Do not retain presented ID data | No PII field exists anywhere in the schema — [`DATA_MODEL.md`](DATA_MODEL.md) |
| Do not transmit presented ID data | The platform-channel DTO cannot carry it — [ADR-0001](adr/0001-flutter-plus-native-tap.md) |
| Request the minimum necessary elements | `age_at_least_21`, portrait, given/family name only. No full DOB, no address, no document number. |
| No secondary use (marketing, profiling, resale) | No PII to use; no analytics SDK in the verification module |
| Business entity vetting | Entity formation and vetting is on the [critical path](ROADMAP.md#critical-path) |
| Human-facing display only | The attendant makes the call; no automated matching |

**Violating Apple's terms means entitlement revocation, which means the product
ceases to function.** That is a more immediate existential risk than a
regulatory fine, and it is why zero-retention is structural here rather than a
configurable setting.

Note the interaction with your product roadmap: any future feature that wants to
*remember* a patron (banned-patron lists, repeat-visit tracking) collides
directly with these terms on the Apple rail. Such features are likely only
viable on a Data Transfer entitlement, or on a non-Apple rail, and need
independent legal review. Do not promise them to a venue before that review.

---

## 2. Biometric privacy law — why we don't do face matching

| Statute | Relevance |
|---|---|
| **Illinois BIPA** | Private right of action, statutory damages per violation. The most dangerous US privacy statute for this product class. |
| **Texas CUBI** | AG enforcement, per-violation penalties |
| **Washington HB 1493** | Consent requirements for biometric identifiers |
| **Colorado / other state privacy acts** | Biometrics as sensitive data, consent + minimization duties |

Running a face-match algorithm over a portrait would likely create a "biometric
identifier" and pull TapID directly into BIPA's scope, complete with written-consent
and retention-schedule obligations at the door of every bar in Chicago.

**Design response:** TapID never processes the portrait. Apple displays it; a
human compares it. The portrait is never encoded, stored, transmitted, or
analyzed. This keeps the highest-liability statute out of scope entirely — which
is worth more than the convenience of automated matching.

This is also why [ADR-0003](adr/0003-zero-retention.md) rejects the "configurable
retention" option that looks more flexible on a product roadmap.

---

## 3. Consumer privacy statutes

CCPA/CPRA, and the growing set of state analogues, impose duties proportional to
what you collect. TapID's posture:

| Duty | Position |
|---|---|
| Notice at collection | Venue-facing signage language provided in the onboarding kit |
| Right to know / access | We hold no patron identifiers, so there is nothing to return |
| Right to delete | Nothing to delete |
| Data minimization | Enforced structurally |
| Sensitive data handling | ID data never persists |

**The strategic value of zero-retention is that these duties mostly evaporate.**
A patron cannot be re-identified from `{venue, timestamp, over21: true, CA}`.
Under the configurable-retention alternative, TapID would become a
service-provider processing sensitive personal information for thousands of
venues, with DSAR handling, retention schedules, and breach-notification
obligations in every state — a compliance organization, not just a feature.

**Employee data is a separate matter and does not evaporate.** Staff names,
PINs, and shift records are ordinary employment data, subject to normal privacy
and retention rules. Do not let the "we store no PII" framing obscure this —
it applies to patrons, not to staff.

---

## 4. Alcohol service law

State liquor authorities set what constitutes an acceptable good-faith age check,
and they have not uniformly caught up to digital IDs.

**Open questions requiring per-state legal answers before launch in that state:**

1. Does the state's statute accept a digital ID as satisfying the licensee's
   verification duty — or does it still require inspection of a physical card?
2. Does the state's affirmative-defense / safe-harbor provision extend to
   electronic verification records?
3. Are there recordkeeping requirements TapID's event log must satisfy in form,
   not just substance?
4. Does the state require a physical ID to be *offered* even when a digital ID is
   presented?

Question 1 is the commercially decisive one. **Note that a state issuing an
Apple Wallet ID does not necessarily mean its liquor code accepts one for
alcohol service** — these are different agencies and often different statutes.
Do not assume Apple's supported-state list is the same as your legally-viable
launch list.

**Design response:** `minimumAge` and jurisdiction rules are per-venue
server-driven config, so state-by-state differences are configuration rather than
code. Venues in states without clear acceptance can be configured to require a
physical-ID fallback alongside the tap.

---

## 5. What TapID does not prove

Worth stating plainly, because overclaiming here is both a legal risk and a
product-integrity problem. Marketing copy must not exceed this list.

TapID **does** provide:
- Cryptographic proof that a state-issued credential was validly presented
- An authoritative issuer assertion of age ≥ 21
- A tamper-evident, timestamped record attributable to a specific staff member,
  device, and venue

TapID **does not** provide:
- Proof that the presenter is the credential holder — that remains a human
  judgment by the attendant
- Legal immunity for the venue
- Coverage for patrons without a supported digital ID (~85% of patrons today,
  given iPhone-only + ~15 states)
- Detection of a credential holder who has shared their device passcode

The `humanDecision` field exists precisely so the record reflects what actually
happened: the credential was valid *and* a named employee made a judgment call.
Both facts matter in a compliance proceeding, and conflating them would weaken
the record.

---

## 6. Pre-launch checklist

| Item | Owner | Blocking? |
|---|---|---|
| Business entity formed + Apple business vetting | Founder | **Yes — blocks everything** |
| Apple Display-Only entitlement approved | Founder | **Yes** |
| Counsel review of retention posture | Legal | **Yes** |
| Per-state alcohol-law review, launch states | Legal | **Yes, per state** |
| Venue terms of service + DPA template | Legal | Yes |
| Patron-facing notice signage | Product + Legal | Yes |
| Employee data retention policy | Legal | Yes |
| SOC 2 Type I readiness | Eng | No — but chains will ask |
| Penetration test | Eng | No for pilot, yes before scale |
| Insurance: cyber + E&O | Founder | Before first paying venue |

The first four are genuine gates. See [`ROADMAP.md`](ROADMAP.md#critical-path) —
the Apple items have multi-month lead times and should be started before any
significant engineering investment.
