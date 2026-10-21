import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/mock_rail.dart';
import 'package:verifier_app/rails/mock_scenario.dart';
import 'package:verifier_app/rails/verification_outcome.dart';

import '../support/verification_rail_contract.dart';
import '../support/verification_rail_harness.dart';
import '../support/verification_rail_scenario.dart' as contract;

class _MockRailHarness implements VerificationRailTestHarness {
  _MockRailHarness() : rail = MockRail();

  @override
  final MockRail rail;

  @override
  Future<void> scriptNext(contract.VerificationRailScenario scenario) async {
    rail.enqueue(
      MockScenario(
        result: scenario.result,
        ageAtLeast21: scenario.ageAtLeast21,
        issuingJurisdiction: scenario.issuingJurisdiction,
        latency: scenario.latency,
      ),
    );
  }
}

void main() {
  // MockRail is the first real implementation to run the shared contract
  // suite against — the whole point of ADR-0002.
  runVerificationRailContractTests(() => _MockRailHarness());

  group('checkNotReleaseBuild', () {
    test('throws when isReleaseMode is true', () {
      expect(
        () => checkNotReleaseBuild(isReleaseMode: true),
        throwsUnsupportedError,
      );
    });

    test('does not throw when isReleaseMode is false', () {
      expect(() => checkNotReleaseBuild(isReleaseMode: false), returnsNormally);
    });
  });

  group('MockRail without autoLoop', () {
    test('throws StateError once the scripted queue is exhausted', () async {
      final rail = MockRail(
        initialScript: const [
          MockScenario(
            result: RailResult.approved,
            ageAtLeast21: true,
            issuingJurisdiction: 'CA',
            latency: Duration.zero,
          ),
        ],
      );

      await rail.beginVerification();
      await expectLater(rail.beginVerification(), throwsStateError);
    });
  });

  group('MockRail with autoLoop', () {
    test('refills from the original fixture once the queue runs dry', () async {
      final rail = MockRail(
        initialScript: const [
          MockScenario(
            result: RailResult.approved,
            ageAtLeast21: true,
            issuingJurisdiction: 'CA',
            latency: Duration.zero,
          ),
          MockScenario(
            result: RailResult.declined,
            ageAtLeast21: false,
            issuingJurisdiction: 'CA',
            latency: Duration.zero,
          ),
        ],
        autoLoop: true,
      );

      final results = <RailResult>[];
      for (var i = 0; i < 5; i++) {
        results.add((await rail.beginVerification()).result);
      }

      expect(results, [
        RailResult.approved,
        RailResult.declined,
        RailResult.approved,
        RailResult.declined,
        RailResult.approved,
      ]);
    });
  });

  test(
    'MockRail.fromAsset loads and loops the shipped default fixture',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final rail = await MockRail.fromAsset(
        'assets/fixtures/mock_rail_default.json',
      );

      final outcome = await rail.beginVerification();
      expect(outcome.eventId, isNotEmpty);
    },
  );
}
