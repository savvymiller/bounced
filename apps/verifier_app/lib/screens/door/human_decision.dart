/// The attendant's own call, captured independently of the rail's result
/// (docs/DATA_MODEL.md's `humanDecision`/`refusalReason`). The rail reports
/// what the credential says; this is what the attendant actually decided
/// to do about it. The two are recorded separately because a liquor board
/// audit cares about both — and because the attendant's call is always
/// final, even when it disagrees with the rail (e.g. refusing someone the
/// rail approved, for reasons the rail has no way to know about).
enum HumanDecision { allowed, refused }

/// A fixed, small set — matches docs/DATA_MODEL.md's "optional, from a
/// fixed enum" for `refusalReason`.
enum RefusalReason { underage, suspiciousId, other }

extension RefusalReasonLabel on RefusalReason {
  String get label => switch (this) {
    RefusalReason.underage => 'Underage',
    RefusalReason.suspiciousId => 'Suspicious ID',
    RefusalReason.other => 'Other',
  };
}
