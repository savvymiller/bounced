# Technology Stack

**Status:** Design v1

Every technology chosen for TapID, and the specific reason it's the one on this
list rather than an adjacent alternative. Organized by where it sits in the
system. Deeper rationale for the biggest calls lives in the linked ADRs — this
document is the index, not a replacement for them.

---

## Client — verifier app

| Technology | Role | Why this one |
|---|---|---|
| **Flutter / Dart** | App shell — auth, shift management, venue settings, history, offline queue UI | One codebase for ~90% of the app; the tap itself is the only part that can't be Flutter. Also keeps an Android build realistic later, which matters once non-Apple rails (Phase 3) exist. [ADR-0001](adr/0001-flutter-plus-native-tap.md) |
| **Swift** | Native iOS module that hosts the verification rail | Apple's ID Verifier is only reachable from native code — there's no way around this, Flutter can't call it directly. |
| **Pigeon** | Codegen for the Flutter↔Swift platform channel | Generates both sides from one schema, so the outcome DTO's field set is enforced by the type system instead of hand-maintained `MethodChannel` maps. This is the actual mechanism that keeps PII from crossing into Dart — see [ADR-0001](adr/0001-flutter-plus-native-tap.md) and [T4](THREAT_MODEL.md#t4-pii-leakage-via-client-logs). |
| **ProximityReader** (Apple framework) | The real verification rail — reads the Apple Wallet credential over NFC | Not a choice — it's Apple's only framework for this, gated behind the ID Verifier entitlement. [ADR-0004](adr/0004-display-only-tier.md) covers which tier (Display Only) and why. |
| **Drift** | Local database ORM over SQLite, backs the offline outbox | Typed queries and migrations for the outbox table, on a well-understood embedded engine. [ADR-0005](adr/0005-offline-first-outbox.md) |
| **SQLCipher** | Transparent encryption for the local Drift database | The outbox is the only thing persisted on a device that's frequently lost in a dark, crowded room — see [T3](THREAT_MODEL.md#t3-lost-or-stolen-verifier-device). |
| **iOS Keychain** (`AfterFirstUnlockThisDeviceOnly`) | Storage for the SQLCipher key and the device's long-lived credential | Non-exportable, hardware-backed, and scoped so a stolen device's storage doesn't yield a usable key or a transferable credential. |
| **App Attest** | Cryptographic proof that a request came from a genuine, unmodified TapID binary on genuine Apple hardware | This is what turns a submitted event from a claim into evidence — the core defense against [T1, forged attestations](THREAT_MODEL.md#t1-forged-attestations), which is the single biggest threat to the product's value. |

---

## Backend — AWS

Chosen as a set for one reason: nightlife traffic is extreme and bursty (~95% of
annual volume in ~6 hours a week), which specifically favors pay-per-use over
anything with a steady-state cost floor. Full reasoning in
[ADR-0006](adr/0006-serverless-aws.md).

| Technology | Role | Why this one |
|---|---|---|
| **API Gateway (HTTP API)** | Public entry point for all client requests | Cheaper and lower-latency than REST API; none of REST API's extra features (usage plans, request validation templates) are needed here. |
| **Lambda** (TypeScript, ARM/Graviton) | All request handlers | Scales to zero on a quiet Tuesday and absorbs a Saturday spike with no capacity planning. Graviton for the standard ~20% price/performance win on stateless compute. |
| **DynamoDB** (single table, on-demand) | Primary operational store | Access patterns are few, known, and key-based — the case single-table design actually fits, rather than a fashionable misuse of it. On-demand billing matches the burst profile directly. [`DATA_MODEL.md`](DATA_MODEL.md) |
| **DynamoDB Streams** | Change feed off the table | Turns every write into an event without the ingest path knowing or caring who's listening. |
| **EventBridge** | Event bus fed by Streams | The extension point for every future feature (banned lists, POS integration, occupancy counting) — each is a new subscriber, never a change to ingest. |
| **Kinesis Firehose** | Delivers the event stream to S3 | Managed batching/buffering into Parquet without a custom consumer to operate. |
| **S3** (Parquet, date-partitioned) | Long-term event archive, 7-year retention | Cheap at scale, and safe to keep long-term specifically because the schema holds no PII — a breach of the archive discloses that a check happened, not who was checked. [ADR-0003](adr/0003-zero-retention.md) |
| **Athena** | Ad-hoc and compliance-export queries over the S3 archive | Keeps unbounded historical queries off the operational DynamoDB table entirely — a two-year liquor-board export must never be able to degrade a Saturday night at the door. |
| **Glue** | Catalog for the Athena tables | Standard pairing with Firehose→S3→Athena; schema-on-read without hand-maintained DDL. |
| **AWS AppConfig** | Server-driven jurisdiction list, feature flags, kill switches | The highest-value config in the system — Apple adds supported states on its own schedule, and hardcoding that list would mean an App Store release every time one is added. Cached locally with a TTL so it still works offline. |
| **Cognito** | Auth for the venue web dashboard (manager/owner roles), with MFA | Separate entirely from door-device auth, which is App Attest + shift claims, not user logins — see [`API.md`](API.md#auth-model) for why door staff need a different model. |
| **CloudFront + WAF** | Edge in front of API Gateway | Absorbs volumetric/DDoS traffic and basic bot patterns before they reach Lambda; standard perimeter for a public API. |
| **SQS** | Per-tenant webhook delivery queue, with retry and DLQ | Isolates a slow or broken tenant webhook from every other tenant's delivery. |
| **SNS** | Operational alerting | Fan-out for on-call notification when rollup anomalies or sync failures cross a threshold. |
| **X-Ray** | Distributed tracing | Tracing across Lambda → Streams → EventBridge is genuinely harder to reason about than a single process; built in from day one rather than retrofitted once something is already confusing in production. |
| **CloudWatch** | Logs, metrics, alarms | Structured logs only, with an allowlisted key set — deliberately constrained so PII can't leak into logs even by accident. [T4](THREAT_MODEL.md#t4-pii-leakage-via-client-logs) |
| **KMS** | Per-tenant envelope encryption keys | Not needed for v1's pooled isolation model, but it's the mechanism the growth-tier tenant isolation upgrade uses — see [`ARCHITECTURE.md`](ARCHITECTURE.md#33-multi-tenancy). |

---

## Infrastructure & delivery

| Technology | Role | Why this one |
|---|---|---|
| **Terraform (HCL)** | Provisions every AWS resource in the system | More portable and more broadly held as a skill than CDK; this stack (API Gateway, Lambda, DynamoDB, EventBridge, AppConfig) is well-trodden enough that mature Terraform modules cover it without missing CDK's higher-level abstractions. Chosen over CDK explicitly — see [ADR-0006](adr/0006-serverless-aws.md#alternatives-considered). |
| **GitHub Actions** | CI — lint, format, typecheck, test, deploy | Standard choice given the repo already lives on GitHub; no separate CI system to operate. |

**Explicitly not used: Ansible.** Ansible configures state on machines that stay
running, and this architecture has no persistent compute anywhere — no VMs, no
bastion hosts, no self-managed containers. Terraform alone provisions
everything. See [ADR-0006](adr/0006-serverless-aws.md#alternatives-considered)
for the full reasoning.

---

## Conventions & formats

| Choice | Role | Why this one |
|---|---|---|
| **ULID** | Client-generated event IDs | Used as the idempotency key for batch ingest — sortable by time (unlike UUIDv4) and generatable offline with no coordination, which matters since events are created with no network present. |
| **JWT** | Bearer tokens for device and dashboard auth | Standard, statelessly verifiable by the Lambda authorizer without a database round-trip per request. |
| **Parquet** | Storage format for the S3 event archive | Columnar, so Athena queries over years of history stay cheap and fast compared to row-oriented JSON/CSV. |

---

## Explicitly rejected

Worth keeping visible, since "why didn't we use X" is a fair question for a few
of these:

| Rejected | In favor of | Why |
|---|---|---|
| ECS Fargate + Aurora Serverless v2 | Lambda + DynamoDB | Aurora Serverless v2 has a minimum ACU floor — it bills continuously through the ~162 quiet hours a week, the worst fit for this traffic shape. [ADR-0006](adr/0006-serverless-aws.md#alternatives-considered) |
| Single Lambda monolith | Per-purpose Lambdas | Would couple the door-critical ingest path to dashboard/export code, letting a slow export query contend with a tap. |
| AppSync/GraphQL | REST over API Gateway | The hot path is one batch-write endpoint that gains nothing from GraphQL. |
| AWS CDK | Terraform | Same-language-as-app-code advantage wasn't worth the narrower, more AWS-specific skill set. [ADR-0006](adr/0006-serverless-aws.md#alternatives-considered) |
| Ansible | Terraform (alone) | No persistent compute exists for it to configure. |
| React Native | Flutter | Same native-module requirement as Flutter for the tap, with a weaker typed-codegen story than Pigeon for the boundary that most needs to be locked down. [ADR-0001](adr/0001-flutter-plus-native-tap.md) |
| Full native SwiftUI app | Flutter + native module | Both prior prototypes in this workspace (`BouncerCheck/`, `id-check/`) took this path and neither reached the entitlement — no evidence it was faster, and it forecloses Android entirely. [ADR-0001](adr/0001-flutter-plus-native-tap.md) |

---

## What's deliberately not pinned yet

A few specifics are left open at the design stage on purpose — pinning them now
would be guessing:

- **Exact ProximityReader API symbols and initializer signatures.** These move
  between iOS releases; must be verified in Xcode against the actual SDK version
  at build time, not trusted from memory or from this repo's docs. Flagged in
  [`ARCHITECTURE.md`](ARCHITECTURE.md#1-the-constraint-that-shapes-everything).
- **Node.js runtime version for Lambda.** Should track whatever AWS's current
  supported LTS is at the time PR-03 lands, not a version chosen today that may
  be stale by then.
- **Dart/Flutter SDK version.** Same reasoning — pin at the time `flutter create`
  actually runs.
