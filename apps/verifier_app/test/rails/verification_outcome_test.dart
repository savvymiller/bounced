import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/verification_outcome.dart';

void main() {
  test('VerificationOutcome value equality', () {
    final occurredAt = DateTime.utc(2026, 7, 29, 4, 12, 33);
    VerificationOutcome build() => VerificationOutcome(
      eventId: 'evt_01H8X',
      result: RailResult.approved,
      ageAtLeast21: true,
      issuingJurisdiction: 'CA',
      occurredAt: occurredAt,
      readLatency: const Duration(milliseconds: 1840),
    );

    expect(build(), equals(build()));
    expect(build().hashCode, equals(build().hashCode));
  });
}
