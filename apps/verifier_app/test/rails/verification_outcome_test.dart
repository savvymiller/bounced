import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/src/generated/verification_rail_api.g.dart';
import 'package:verifier_app/rails/verification_outcome.dart';

void main() {
  group('VerificationOutcome.fromMessage', () {
    test('maps every field, including nullable ones, when present', () {
      final message = VerificationOutcomeMessage(
        eventId: 'evt_01H8X',
        result: RailResultMessage.approved,
        ageAtLeast21: true,
        issuingJurisdiction: 'CA',
        occurredAtEpochMs: 1785000000000,
        readLatencyMs: 1840,
      );

      final outcome = VerificationOutcome.fromMessage(message);

      expect(outcome.eventId, 'evt_01H8X');
      expect(outcome.result, RailResult.approved);
      expect(outcome.ageAtLeast21, isTrue);
      expect(outcome.issuingJurisdiction, 'CA');
      expect(
        outcome.occurredAt,
        DateTime.fromMillisecondsSinceEpoch(1785000000000, isUtc: true),
      );
      expect(outcome.readLatency, const Duration(milliseconds: 1840));
    });

    test(
      'tolerates null ageAtLeast21/issuingJurisdiction (e.g. readFailed)',
      () {
        final message = VerificationOutcomeMessage(
          eventId: 'evt_01H8Y',
          result: RailResultMessage.readFailed,
          occurredAtEpochMs: 1785000000000,
          readLatencyMs: 900,
        );

        final outcome = VerificationOutcome.fromMessage(message);

        expect(outcome.result, RailResult.readFailed);
        expect(outcome.ageAtLeast21, isNull);
        expect(outcome.issuingJurisdiction, isNull);
      },
    );

    test('every RailResultMessage case maps to its RailResult counterpart', () {
      const expected = {
        RailResultMessage.approved: RailResult.approved,
        RailResultMessage.declined: RailResult.declined,
        RailResultMessage.expired: RailResult.expired,
        RailResultMessage.unsupportedIssuer: RailResult.unsupportedIssuer,
        RailResultMessage.readFailed: RailResult.readFailed,
        RailResultMessage.cancelled: RailResult.cancelled,
      };

      for (final entry in expected.entries) {
        final message = VerificationOutcomeMessage(
          eventId: 'evt',
          result: entry.key,
          occurredAtEpochMs: 0,
          readLatencyMs: 0,
        );
        expect(
          VerificationOutcome.fromMessage(message).result,
          entry.value,
          reason: entry.key.name,
        );
      }
    });
  });

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
