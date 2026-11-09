import 'package:verifier_app/rails/verification_rail.dart';

import 'verification_rail_scenario.dart';

/// Lets the shared contract suite ([runVerificationRailContractTests]) drive
/// any [VerificationRail] implementation through specific, deterministic
/// outcomes.
///
/// [scriptNext] enqueues a scenario (FIFO); each call to
/// [VerificationRail.beginVerification] must consume exactly one queued
/// scenario, in the order scripted. A harness that receives a
/// [VerificationRail.beginVerification] call with nothing queued should
/// throw a [StateError] — that is a test-authoring bug, not a case the
/// contract suite is meant to exercise.
///
/// Every rail's own test file provides one of these (wrapping `MockRail` or
/// `Pdf417Rail`) and calls the same contract suite against it.
abstract class VerificationRailTestHarness {
  /// The rail under test.
  VerificationRail get rail;

  /// Enqueues [scenario] as the outcome the next unconsumed
  /// [VerificationRail.beginVerification] call must produce.
  Future<void> scriptNext(VerificationRailScenario scenario);
}
