/// Facts about any age-verification mechanism, rail-independent by design —
/// not artifacts of any one rail's API.
enum RailResult {
  approved,
  declined,
  expired,
  unsupportedIssuer,
  readFailed,
  cancelled,
}

/// The result of a single verification attempt. No name, no DOB, no
/// portrait, no document identifier — just enough for the door screen and
/// the backend event log.
class VerificationOutcome {
  const VerificationOutcome({
    required this.eventId,
    required this.result,
    required this.occurredAt,
    required this.readLatency,
    this.ageAtLeast21,
    this.issuingJurisdiction,
  });

  /// Client-generated, doubles as the server-side idempotency key.
  final String eventId;

  final RailResult result;

  /// Authoritative only when non-null — absent for outcomes where no
  /// credential was successfully read (e.g. [RailResult.readFailed]).
  final bool? ageAtLeast21;

  /// State only, e.g. "CA" — never a document number. Null when the rail
  /// never got far enough to learn it.
  final String? issuingJurisdiction;

  /// Device clock. Not fully trustworthy on its own — the server also
  /// records its own receive time.
  final DateTime occurredAt;

  final Duration readLatency;

  @override
  bool operator ==(Object other) =>
      other is VerificationOutcome &&
      other.eventId == eventId &&
      other.result == result &&
      other.ageAtLeast21 == ageAtLeast21 &&
      other.issuingJurisdiction == issuingJurisdiction &&
      other.occurredAt == occurredAt &&
      other.readLatency == readLatency;

  @override
  int get hashCode => Object.hash(
    eventId,
    result,
    ageAtLeast21,
    issuingJurisdiction,
    occurredAt,
    readLatency,
  );

  @override
  String toString() =>
      'VerificationOutcome(eventId: $eventId, result: $result, '
      'ageAtLeast21: $ageAtLeast21, issuingJurisdiction: $issuingJurisdiction, '
      'occurredAt: $occurredAt, readLatency: $readLatency)';
}
