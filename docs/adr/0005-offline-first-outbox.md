# ADR-0005 — Offline-first with an encrypted local outbox

**Status:** Accepted · **Date:** 2026-07-29

## Context

Bars have bad connectivity. Basements, back rooms, thick walls, and a few hundred
people saturating the same cell tower on a Saturday night. Meanwhile the verifier
device is at a door where a line is forming.

The enabling fact: **verification does not need the network.** The iOS Secure
Element validates the issuing state's signature locally. Nothing about deciding
"is this credential valid and does it assert over-21" requires a server.

So any network dependency on the critical path would be one we *chose* to add.

## Decision

The network is never on the critical path. Verification completes fully offline;
outcomes are written to an encrypted local outbox and drained asynchronously.

```
tap → local validation (OS) → attendant decision
    → outbox write (durable, committed before UI advances)
    → return to ready screen
                              ⋮  (independently, whenever there is signal)
                              └→ batch of ≤50 → POST /events:batch → ack → purge
```

**Storage:** Drift (SQLite) with SQLCipher, key in the iOS Keychain as
`AfterFirstUnlockThisDeviceOnly`. Must survive force-quit, reboot, and 72h
offline.

**Sync:** exponential backoff with jitter, triggered by connectivity changes and
a periodic background task. Batches of up to 50, capped by payload size.

**Idempotency:** each event carries a client-generated ULID used as the server's
idempotency key. A `duplicate` response is treated as success and the local row is
purged. This is what makes aggressive retries safe — the client can retry
indefinitely without ever double-counting.

**Ordering:** not required. Events are independent and carry their own timestamps,
so the outbox drains in any order. This deliberately avoids head-of-line blocking,
where one poison event would stall every subsequent one.

**Failure surface:** door staff see *nothing* about sync state. Queue depth and
sync health are manager-role concerns, surfaced in settings and via backend
alerting. A bouncer with a line forming must not be shown a network error they
cannot act on.

## Rationale

If TapID stops the door, the venue stops using TapID — permanently. Availability
of the door matters more than freshness of the dashboard, and the two are in
tension only if we let them be.

Committing the outbox write *before* advancing the UI is the ordering that makes
the audit trail trustworthy: an event that the attendant saw resolve is durably
recorded even if the app is killed a millisecond later.

Treating `duplicate` as success is the small detail that makes the whole loop
robust. Without it, a client that gets an ack it didn't receive (dropped response)
either loses the event or resubmits forever.

## Consequences

**Good**
- Door works through total backend outage, dead cell zones, and AWS incidents
- Batching reduces request volume by ~50×, which is also most of the cost story
- Retries are free and unbounded, so no event is lost to transient failure
- Dashboard lag is decoupled from door reliability

**Bad**
- Dashboards can be stale — a venue offline all night shows nothing until sync.
  Must be communicated in the UI ("last synced 3h ago") so a manager does not
  read staleness as inactivity.
- Real-time features (live occupancy, instant cross-venue alerts) are not possible
  for offline devices. Accepted; they are Phase 4 and inherently best-effort.
- Encrypted local storage adds key-management complexity
- Unsynced events are lost if a device is wiped before draining
  ([`THREAT_MODEL.md`](../THREAT_MODEL.md#t3-lost-or-stolen-verifier-device)).
  Accepted: they are records of checks, not the checks themselves.
- Device-clock trust: `occurredAt` comes from a venue-controlled device. Handled
  by recording server-side `receivedAt` and `clockSkewMs` rather than by
  rejecting skewed events, since legitimate offline queuing produces large delays
  ([`THREAT_MODEL.md`](../THREAT_MODEL.md#t1-forged-attestations)).

## Alternative considered

**Online-required ingest.** Simpler backend, stronger real-time audit guarantees,
and no local encryption to manage. Rejected because a dropped connection would
stop the door, which is the one failure this product cannot have. The audit
guarantees it would buy are recovered instead via App Attest and append-only
records.
