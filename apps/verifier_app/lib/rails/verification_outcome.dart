import 'src/generated/verification_rail_api.g.dart';

/// Mirrors docs/DATA_MODEL.md's VerificationEvent.railResult. Rail-independent
/// by design (ADR-0007) — these are facts about any age-verification
/// mechanism, not artifacts of Apple's API.
enum RailResult {
  approved,
  declined,
  expired,
  unsupportedIssuer,
  readFailed,
  cancelled,
}

/// The result of a single tap. This is the only thing allowed to cross the
/// native/Dart boundary — see ADR-0001 and ADR-0003.
///
/// No name, no DOB, no portrait, no document identifier. Adding a field
/// requires a new ADR referenced in the commit message; CI enforces this
/// (PR-24).
class VerificationOutcome {
  const VerificationOutcome({
    required this.eventId,
    required this.result,
    required this.occurredAt,
    required this.readLatency,
    this.ageAtLeast21,
    this.issuingJurisdiction,
  });

  /// Client-generated ULID. Doubles as the server-side idempotency key —
  /// see docs/DATA_MODEL.md's VerificationEvent.SK.
  final String eventId;

  final RailResult result;

  /// Authoritative only when non-null — absent for outcomes where no
  /// credential was successfully read (e.g. [RailResult.readFailed]).
  final bool? ageAtLeast21;

  /// State only, e.g. "CA" — never a document number. Null when the rail
  /// never got far enough to learn it.
  final String? issuingJurisdiction;

  /// Device clock. Not fully trustworthy on its own — the server records
  /// its own receive time and flags implausible skew; see DATA_MODEL.md.
  final DateTime occurredAt;

  final Duration readLatency;

  factory VerificationOutcome.fromMessage(VerificationOutcomeMessage message) {
    return VerificationOutcome(
      eventId: message.eventId!,
      result: _resultFromMessage(message.result!),
      ageAtLeast21: message.ageAtLeast21,
      issuingJurisdiction: message.issuingJurisdiction,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        message.occurredAtEpochMs!,
        isUtc: true,
      ),
      readLatency: Duration(milliseconds: message.readLatencyMs!),
    );
  }

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

RailResult _resultFromMessage(RailResultMessage message) => switch (message) {
  RailResultMessage.approved => RailResult.approved,
  RailResultMessage.declined => RailResult.declined,
  RailResultMessage.expired => RailResult.expired,
  RailResultMessage.unsupportedIssuer => RailResult.unsupportedIssuer,
  RailResultMessage.readFailed => RailResult.readFailed,
  RailResultMessage.cancelled => RailResult.cancelled,
};
