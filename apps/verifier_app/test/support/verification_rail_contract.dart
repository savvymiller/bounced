import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/verification_outcome.dart';

import 'verification_rail_harness.dart';
import 'verification_rail_scenario.dart';

/// The suite every [VerificationRail] implementation must pass, identically
/// — `MockRail` (PR-07) today, `AppleWalletRail` (PR-30) once Apple approves
/// this project, and any future rail (barcode, ISO 18013-5) after that. Per
/// ADR-0002, this is written before any implementation exists; a
/// self-test against a throwaway in-memory stub
/// (test/rails/verification_rail_contract_selftest_test.dart) proves the
/// suite itself is runnable and correct ahead of PR-07.
///
/// Call this from a rail's own `*_test.dart` file:
///
/// ```dart
/// void main() {
///   runVerificationRailContractTests(() => _MockRailHarness());
/// }
/// ```
void runVerificationRailContractTests(
  FutureOr<VerificationRailTestHarness> Function() createHarness,
) {
  group('VerificationRail contract', () {
    late VerificationRailTestHarness harness;

    setUp(() async {
      harness = await createHarness();
    });

    group('every outcome case', () {
      for (final scenario in VerificationRailScenario.all) {
        test(scenario.result.name, () async {
          await harness.scriptNext(scenario);
          final outcome = await harness.rail.beginVerification();

          expect(outcome.result, scenario.result);
          expect(outcome.ageAtLeast21, scenario.ageAtLeast21);
          expect(outcome.issuingJurisdiction, scenario.issuingJurisdiction);
          expect(outcome.eventId, isNotEmpty);
          // Generous tolerance: this proves latency is plumbed through at
          // all, not that a rail hits a precise figure — real-device
          // latency tuning is PR-33, not a contract-suite concern.
          expect(
            outcome.readLatency.inMilliseconds,
            closeTo(scenario.latency.inMilliseconds, 250),
          );
        });
      }
    });

    test('readLatency is never negative, regardless of outcome', () async {
      await harness.scriptNext(VerificationRailScenario.readFailed);
      final outcome = await harness.rail.beginVerification();

      expect(outcome.readLatency, greaterThanOrEqualTo(Duration.zero));
    });

    test('every call gets a unique eventId', () async {
      await harness.scriptNext(VerificationRailScenario.approved);
      final first = await harness.rail.beginVerification();
      await harness.scriptNext(VerificationRailScenario.approved);
      final second = await harness.rail.beginVerification();

      expect(first.eventId, isNot(equals(second.eventId)));
    });

    test(
      'concurrent invocations each resolve independently, in script order',
      () async {
        await harness.scriptNext(VerificationRailScenario.approved);
        await harness.scriptNext(VerificationRailScenario.declined);

        final results = await Future.wait([
          harness.rail.beginVerification(),
          harness.rail.beginVerification(),
        ]);

        expect(results.map((o) => o.eventId).toSet(), hasLength(2));
        expect(results.map((o) => o.result).toList(), [
          RailResult.approved,
          RailResult.declined,
        ]);
      },
    );

    test('isAvailable can be queried without throwing', () async {
      expect(await harness.rail.isAvailable(), isA<bool>());
    });
  });
}
