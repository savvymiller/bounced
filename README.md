# TapID

Digital ID age verification at the door. A patron taps their iPhone (Apple Wallet
ID) against a door attendant's iPhone; the attendant sees a portrait, name, and a
state-attested "over 21" — and the venue gets a tamper-evident record that the
check happened.

**Status: design phase. No implementation yet.** This repository currently
contains architecture and planning documents only.

---

## Start here

| Document | What it covers |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | **Read first.** System design, components, flows, scale analysis |
| [`docs/DELIVERY_PLAN.md`](docs/DELIVERY_PLAN.md) | 40-PR breakdown, dependency graph, parallel tracks |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phasing, and the Apple entitlement critical path |
| [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) | DynamoDB single-table design, access patterns |
| [`docs/API.md`](docs/API.md) | Endpoints, the shift-based auth model, error contract |
| [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) | Attacker-by-attacker analysis |
| [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) | Apple terms, BIPA/CCPA, state alcohol law |
| [`docs/adr/`](docs/adr/) | Seven decision records with rationale and trade-offs |

## v1 scope

Decided deliberately; each is revisited in an ADR.

- **Apple Wallet only** — no Android, no barcode, no ISO 18013-5 rail yet
- **Display-Only tier** — Apple renders the ID; a human makes the call ([ADR-0004](docs/adr/0004-display-only-tier.md))
- **Zero retention** — no patron PII is stored or transmitted, anywhere ([ADR-0003](docs/adr/0003-zero-retention.md))
- **Multi-tenant B2B** — organizations own venues; staff claim shifts on shared devices
- **Offline-first** — the door works with no network at all ([ADR-0005](docs/adr/0005-offline-first-outbox.md))

## Stack

- **Client:** Flutter, with a native Swift module for the tap ([ADR-0001](docs/adr/0001-flutter-plus-native-tap.md))
- **Backend:** AWS — API Gateway, Lambda, DynamoDB, EventBridge, AppConfig ([ADR-0006](docs/adr/0006-serverless-aws.md))
- **IaC:** CDK (TypeScript)

## Three things to know before writing code

**1. The Apple entitlement is the critical path, and it is not an engineering task.**
ID Verifier requires business vetting and approval measured in weeks to months,
with no guaranteed outcome. Two earlier prototypes in this workspace
(`BouncerCheck/`, `id-check/`) each built a working app shell and then stalled at a
stubbed verifier. **Start the application before significant engineering begins.**
See [`docs/ROADMAP.md`](docs/ROADMAP.md#critical-path).

**2. The product is the audit trail, not the tap.** Apple and the issuing state
already do the hard cryptography. TapID's value is producing a record a venue can
show a liquor board — which means resisting record forgery by the venue itself is
the central security problem, not an afterthought. See
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md#t1-forged-attestations).

**3. The competition is a two-second glance at a plastic card.** Anything that
makes the door slower loses, regardless of how good the cryptography is. The
<3s p95 tap-to-decision figure is a product requirement.

## Coverage reality

v1 verifies patrons who have **an iPhone** *and* **a supported state's Wallet ID**
— on the order of 15 jurisdictions today. That is a minority of any real door's
traffic. The architecture treats this as a measured problem: every unsupported
read is logged as `unsupportedIssuer`, so the rollup data tells you exactly how
much a barcode rail would add and which states to prioritize
([`docs/ROADMAP.md`](docs/ROADMAP.md#phase-3--coverage-expansion)).

## Layout

```
docs/            architecture, design, ADRs   ← everything, currently
apps/            Flutter app + native iOS module   (not yet created)
services/api/    Lambda handlers                   (not yet created)
infra/cdk/       AWS CDK                           (not yet created)
```

## Contributing

Read [`docs/DELIVERY_PLAN.md`](docs/DELIVERY_PLAN.md) first — work is decomposed
into sized, ordered PRs with an explicit dependency graph.

- Branches: `track-b/05-rail-interface`
- Conventional Commits; squash-merge
- Link the ADR or design doc each PR implements
- **Changes to the outcome DTO, the DynamoDB schema, or the retention posture
  require a new ADR in the same PR.**

> ⚠️ [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) is engineering analysis, not legal
> advice. Age verification for alcohol service is regulated per-state and
> sometimes per-city. Retain counsel before the first paying venue.
