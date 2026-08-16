# ADR-0006 — Serverless AWS: API Gateway + Lambda + DynamoDB

**Status:** Accepted · **Date:** 2026-07-29

## Context

Nightlife traffic is one of the most extreme burst profiles in consumer software:

```
Mon 10am  ▏                             ~0 req/s
Thu 11pm  ████▏                         moderate
Sat 11pm  ████████████████████████████  peak
Sat 2am   ████████████████████████████  second peak at close
Sun 6am   ▏                             ~0 req/s
```

Roughly **95% of annual volume arrives in about 6 hours per week**, with sharp
spikes at open and close. Provisioning for peak means paying for peak 24/7 at
~28× the average utilization.

The workload also has favorable properties: writes vastly outnumber reads, access
patterns are few and known in advance, and requests are independent and stateless.

## Decision

- **API Gateway HTTP API** — cheaper and lower-latency than REST API; we need none
  of the REST API's extra features
- **Lambda** (TypeScript, ARM/Graviton) for handlers
- **DynamoDB single table, on-demand billing** ([`DATA_MODEL.md`](../DATA_MODEL.md))
- **DynamoDB Streams → EventBridge** for fan-out
- **Kinesis Firehose → S3 (Parquet) → Athena** for analytics and compliance export
- **AWS AppConfig** for the jurisdiction list, feature flags, and kill switches
- **CDK (TypeScript)** for IaC
- **Scheduled provisioned concurrency**, Thu–Sat 8pm–3am, on the ingest and
  authorizer Lambdas

## Rationale

**Cost tracks usage, not peak.** On-demand DynamoDB and per-request Lambda mean a
quiet Tuesday costs nearly nothing. At pilot scale a venue's infrastructure cost
lands in the low single-digit dollars per month — which matters enormously for
landing the first customers, where the alternative is paying for idle Fargate
tasks and RDS instances all week.

**Scaling requires no capacity planning.** DynamoDB on-demand absorbs the Saturday
spike automatically. The team should be validating the product at real doors, not
tuning autoscaling groups.

**The access patterns genuinely fit DynamoDB.** Nine known query patterns, all
key-based, none requiring joins or ad-hoc filtering. This is the case where
single-table design is a good fit rather than a fashionable one — and where a
relational schema's flexibility would buy little.

**Batched ingest keeps request volume low.** With outbox batches of 50
([ADR-0005](0005-offline-first-outbox.md)), even a very busy door is a few
requests per minute. Lambda invocation count stays modest relative to tap volume.

**Scheduled provisioned concurrency** is the specific answer to the one real
serverless objection here: cold starts. A 1.5s cold start at a door with a line is
unacceptable, but we know precisely when doors are busy. Paying for warm capacity
during those windows only is a fraction of running warm all week.

**AppConfig for the jurisdiction list** deserves its own note — it is the
highest-value flag in the system. Apple adds supported states on their own
schedule, and hardcoding that list would require an App Store release each time.
`railEnabled` also gives us a kill switch if Apple changes something under us.

## Consequences

**Good**
- Cost proportional to actual verifications
- No capacity planning; scales to thousands of venues without redesign
- Managed availability; small ops surface for a small team
- EventBridge makes every future feature an additive subscriber rather than a
  change to the ingest path

**Bad**
- **Cold starts** — mitigated as above, but not eliminated
- **DynamoDB access patterns are hard to change later.** New query shapes may
  require a GSI or a migration, where SQL would just need a new `WHERE`. This is
  the real cost of the choice, and it is why the access patterns are enumerated
  in [`DATA_MODEL.md`](../DATA_MODEL.md) before any code is written.
- **Meaningful AWS lock-in.** Accepted deliberately — for a small team, leverage
  from managed services outweighs portability.
- Local development requires emulation (DynamoDB Local, SAM) or a per-developer
  cloud stack
- Distributed tracing across Lambda + Streams + EventBridge is harder to reason
  about than a single process; X-Ray from day one, not retrofitted

**Deliberately deferred:** multi-region. The API tier is stateless and DynamoDB
Global Tables provide the path, so this is a configuration change when west-coast
latency or a regional-failover requirement justifies it — not an architectural one.

## Alternatives considered

**ECS Fargate + Aurora Serverless v2.** More familiar, easier local dev, real SQL
flexibility for evolving queries. Rejected: Aurora Serverless v2 has a minimum
ACU floor, so it bills continuously through the ~162 hours a week of near-zero
traffic — the worst possible fit for this profile. Would be the right answer if
traffic were steady.

**Single Lambda monolith (Lambda-lith).** Simpler deploys and one warm container.
Rejected: it couples the door-critical ingest path to dashboard and export code,
so a slow export query could contend with a tap. The separation between ingest and
export is a deliberate availability boundary ([`API.md`](../API.md#compliance-export--async-by-design)).

**AppSync/GraphQL.** Flexible for dashboard queries, but the hot path is a single
batch-write endpoint that gains nothing from GraphQL, and it adds resolver
complexity plus a second auth integration.
