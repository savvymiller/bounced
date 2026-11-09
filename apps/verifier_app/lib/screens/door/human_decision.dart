/// The attendant's own call, captured independently of the rail's result.
/// The rail reports what the credential says; this is what the attendant
/// actually decided to do about it. The two are recorded separately because
/// the attendant's call is always final, even when it disagrees with the
/// rail (e.g. refusing someone the rail approved, for reasons the rail has
/// no way to know about).
enum HumanDecision { allowed, refused }

/// A fixed, small set of reasons an attendant can give for a refusal.
enum RefusalReason { underage, suspiciousId, other }

extension RefusalReasonLabel on RefusalReason {
  String get label => switch (this) {
    RefusalReason.underage => 'Underage',
    RefusalReason.suspiciousId => 'Suspicious ID',
    RefusalReason.other => 'Other',
  };
}
