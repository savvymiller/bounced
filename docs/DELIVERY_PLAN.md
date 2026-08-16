# Delivery Plan — PR Breakdown

**Status:** Design v1

The work decomposed into independently reviewable pull requests. Rules used:

- **One concern per PR.** A reviewer should hold the whole change in their head.
- **Target ≤400 changed lines** excluding generated code, lockfiles, and fixtures.
  Anything projected past ~600 is split.
- **Every PR merges green and leaves `main` deployable.** No PR depends on a later
  one to compile or pass CI.
- **Vertical slices where possible.** A PR that delivers a thin end-to-end path is
  more valuable than one that delivers a complete layer, because it validates the
  seams earlier.
- **PRs touching the privacy boundary are deliberately tiny.** PR-05 and PR-24 in
  particular should be small enough to review line-by-line, because they are where
  a mistake is expensive ([`THREAT_MODEL.md`](THREAT_MODEL.md#t4-pii-leakage-via-client-logs)).

`S` ≈ <150 lines · `M` ≈ 150–400 · `L` ≈ 400–600 (justified in notes)

---

## Track A — Foundation

Buildable immediately. Nothing here waits on Apple.

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **01** | Design docs + repo scaffolding | M | — | This documentation set, `.gitignore`, `CODEOWNERS`, PR/issue templates. Docs only. |
| **02** | CI pipeline skeleton | S | 01 | GitHub Actions: lint, format, typecheck, test jobs for Dart + TS. No app code yet — jobs are no-ops that pass. |
| **03** | Terraform bootstrap + environments | M | 02 | Root module, remote state (S3 backend + DynamoDB lock table), `dev`/`staging`/`prod` workspaces, IAM bootstrap, no functional resources. `terraform apply` succeeds on an empty stack. |
| **04** | DynamoDB table module | M | 03 | `tapid-main` table, 3 GSIs, TTL, Streams enabled, per [`DATA_MODEL.md`](DATA_MODEL.md). Includes a `terraform plan` check asserting key schema in CI. |

**Milestone A:** empty but real infrastructure deploying from CI to `dev`.

---

## Track B — The verification seam

The privacy-critical track. Small PRs on purpose.

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **05** | `VerificationRail` interface + Pigeon contract | **S** | 02 | The outcome DTO and rail interface only ([ADR-0001](adr/0001-flutter-plus-native-tap.md), [ADR-0007](adr/0007-single-rail-with-seam.md)). Deliberately tiny — this file defines what PII can never cross. Review line-by-line. |
| **06** | Rail contract test suite | M | 05 | The shared suite both rails must pass: all six outcome cases, latency, concurrent invocation. Written before any implementation. |
| **07** | `MockRail` + scenario fixtures | M | 06 | Fixture-driven mock passing the full suite ([ADR-0002](adr/0002-mock-rail-parity.md)). Release-build compile guard. |
| **08** | Flutter app shell | M | 05 | DI, routing, theming, result types, logging. No features. |
| **09** | Door screen (mock-backed) | M | 07, 08 | The one-big-button UI, outcome display, decision capture. First visible product. |

**Milestone B:** a demoable tap flow on a physical device, mock-backed. Worth
showing to a venue for feedback well before the entitlement lands.

---

## Track C — Durability & sync

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **10** | Encrypted local store | M | 08 | Drift + SQLCipher, Keychain key management, migrations. Includes a force-quit durability test. |
| **11** | Outbox write path | S | 09, 10 | Commit-before-UI-advance ordering ([ADR-0005](adr/0005-offline-first-outbox.md)). Small but load-bearing for audit integrity. |
| **12** | API client + error contract | M | 08 | Typed client, the `retryable` branch, `requestId` propagation per [`API.md`](API.md#error-contract). |
| **13** | Sync engine | **L** | 11, 12 | Batching (≤50), backoff with jitter, connectivity triggers, background task, `duplicate`-as-success purge. Justified L: splitting the retry policy from the drain loop would leave a non-functional half. Heavy test coverage expected. |
| **14** | Sync health surfacing | S | 13 | Queue depth + last-synced in manager settings only. Explicitly *not* shown to door staff. |

**Milestone C:** verifications survive reboot and 72h offline, then drain cleanly.

---

## Track D — Identity, tenancy, ingest

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **15** | Cognito + org/venue/staff model | M | 04 | User pool, roles, tenant entities. |
| **16** | App Attest enrollment (client) | M | 10 | Key generation, attestation, Keychain storage. |
| **17** | App Attest authorizer (Lambda) | M | 04, 16 | Assertion verification, monotonic counter enforcement ([`THREAT_MODEL.md`](THREAT_MODEL.md#t1-forged-attestations)). |
| **18** | Device enrollment endpoints | M | 15, 17 | `POST /devices`, fleet list, `:revoke`. |
| **19** | Shift claim endpoints | M | 15 | Open/close shift, PIN validation, idle auto-close. |
| **20** | Shift UI | M | 09, 19 | Claim/hand-off/end flow on device. |
| **21** | `POST /events:batch` ingest | **L** | 04, 17 | Batch handler, per-item results, idempotency via conditional writes, clock-skew recording. Justified L: per-item result semantics and idempotency are one indivisible correctness story. |
| **22** | Tenant isolation IAM + contract tests | M | 21 | `dynamodb:LeadingKeys` conditions, plus tests asserting cross-tenant reads get `AccessDenied` ([`THREAT_MODEL.md`](THREAT_MODEL.md#t5-cross-tenant-data-access)). |

**Milestone D:** end-to-end — attested tap → outbox → batch → DynamoDB, tenant-isolated.

---

## Track E — Config, rollups, operability

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **23** | AppConfig + `GET /config` + client cache | M | 21 | Server-driven jurisdiction list, flags, kill switch, offline TTL cache. High leverage — avoids an App Store release per new state. |
| **24** | CI privacy guard | **S** | 05, 21 | Fails the build if the outcome DTO gains a field without an ADR reference; dependency allowlist for the verification module. Tiny, and the enforcement mechanism for [ADR-0003](adr/0003-zero-retention.md). |
| **25** | Streams → rollup consumer | M | 21 | Atomic `ADD` daily rollups, including the `unsupportedIssuer` demand counter. |
| **26** | Firehose → S3 Parquet + Glue catalog | M | 21 | Analytics lake, date partitioning, lifecycle to Glacier. |
| **27** | Observability | M | 21 | X-Ray, structured logging with an allowlisted key set, CloudWatch alarms, dashboards. |
| **28** | Scheduled provisioned concurrency | S | 27 | Thu–Sat 8pm–3am warm capacity ([ADR-0006](adr/0006-serverless-aws.md)). |

**Milestone E — Phase 0 complete.** Everything except the real tap. This is the
point at which the only remaining dependency is Apple.

---

## Track F — Real rail (gated on Apple entitlement)

Cannot start until the entitlement is granted. Small track by design — that is the
payoff for [ADR-0002](adr/0002-mock-rail-parity.md).

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **29** | Entitlement + provisioning config | S | 07 | Entitlement file, capability declaration, signing. |
| **30** | `AppleWalletRail` implementation | M | 06, 29 | Real ProximityReader against the contract suite. **Pin exact symbol names to the SDK in Xcode — do not trust remembered signatures, including any in this repo's docs.** |
| **31** | Device capability gating | S | 30 | iPhone XS+ / iOS 17+ detection, graceful messaging otherwise. |
| **32** | Redaction boundary verification | S | 30 | Assert against *real* returned data that nothing beyond the DTO crosses. |
| **33** | Latency instrumentation + tuning | M | 30 | Measure and tune toward the <3s p95 target. |

**Milestone F:** real taps at a real door. Then the Phase 1 field test — a real
venue, a real Saturday, door staff who did not build it.

---

## Track G — First paying venues

| PR | Title | Size | Depends on | Scope |
|---|---|---|---|---|
| **34** | Dashboard shell + auth | M | 15 | Web app, Cognito + MFA, role routing. |
| **35** | Venue summary views | M | 25, 34 | Rollup-backed charts. Never raw-event queries. |
| **36** | Shift & staff management UI | M | 19, 34 | Roster, PIN rotation, shift history. |
| **37** | Fleet management UI | M | 18, 34 | Device status, enrollment, revocation. |
| **38** | Async compliance export | **L** | 26, 34 | `POST /exports`, Athena job, presigned S3 delivery. Justified L: async job orchestration is one unit. Kept off the operational table by design ([`API.md`](API.md#compliance-export--async-by-design)). |
| **39** | Runbooks + on-call | S | 27 | Alert response, escalation. A Saturday-night outage is a lost customer. |
| **40** | Onboarding kit | M | — | Signage, staff training, terms + DPA templates (legal review required — [`COMPLIANCE.md`](COMPLIANCE.md#6-pre-launch-checklist)). |

---

## Dependency graph

```
A: 01 → 02 → 03 → 04 ──────────────┬──────────────┐
                                    │              │
B:      02 → 05 → 06 → 07 → 09      │              │
              ↓     ↑    ↓          │              │
              08 ───┘    │          │              │
                         │          │              │
C:      08 → 10 → 11 → 13 → 14      │              │
              ↓    ↑                │              │
              12 ──┘                │              │
                                    │              │
D:                    15 ←──────────┤              │
                      16 → 17 ←─────┤              │
                      18, 19 → 20   │              │
                      21 ←──────────┘              │
                      22                           │
                                                   │
E:                    23, 24, 25, 26, 27, 28 ←─────┘

F:  [APPLE ENTITLEMENT GATE] → 29 → 30 → 31, 32, 33

G:                    34 → 35, 36, 37, 38 ; 39, 40
```

## Parallelization

Three streams can run concurrently after PR-04:

- **Client:** B → C (rail seam, app shell, outbox, sync)
- **Backend:** D → E (auth, ingest, tenancy, rollups)
- **Infra/ops:** 27, 28 alongside either

The natural integration points are PR-21 (ingest exists, so the client's sync
engine has a real target) and Milestone E.

## Suggested review load

| Track | PRs | Notes |
|---|---|---|
| A | 4 | Mostly config; fast reviews |
| B | 5 | PR-05 needs the most careful review of any PR in the project |
| C | 5 | PR-13 is the largest correctness risk |
| D | 8 | Heaviest track; PR-21 and PR-22 are security-critical |
| E | 6 | PR-24 is small but is the enforcement mechanism for zero-retention |
| F | 5 | Blocked on Apple; small once unblocked |
| G | 7 | Product surface; lower risk |

**40 PRs, ~36 of them S/M.** Four are justified `L` (13, 21, 38, and PR-30's real
possibility of growing), each because splitting would leave a non-functional half
or fragment a single correctness story.

## Conventions

- Branches: `track-b/05-rail-interface`
- Conventional Commits; squash-merge, so the PR title becomes the history entry
- Every PR description links the ADR or design doc it implements
- A PR that changes the outcome DTO, the DynamoDB schema, or the retention posture
  **requires a new ADR in the same PR** — CI enforces this via PR-24
