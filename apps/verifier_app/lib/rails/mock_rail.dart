import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'mock_scenario.dart';
import 'verification_outcome.dart';
import 'verification_rail.dart';

/// Checks the one condition that must hold unconditionally, regardless of
/// any server flag: a release binary must never contain a reachable
/// `MockRail`. Per ADR-0002, this is "belt and braces" alongside the
/// `mockRailAllowed` server flag (PR-23) — a venue must never be able to
/// fabricate an approval by reaching the mock.
///
/// [isReleaseMode] defaults to the real [kReleaseMode] compile-time
/// constant; the parameter exists only so this predicate's logic can be
/// unit-tested (kReleaseMode itself can't be flipped at test time — it's
/// fixed by the build mode of whatever binary is running the test).
@visibleForTesting
void checkNotReleaseBuild({bool isReleaseMode = kReleaseMode}) {
  if (isReleaseMode) {
    throw UnsupportedError(
      'MockRail must never run in a release build (ADR-0002). This check is '
      'unconditional — it does not depend on mockRailAllowed or any other '
      'flag being configured correctly.',
    );
  }
}

/// A first-class, contract-tested implementation of [VerificationRail] —
/// not throwaway scaffolding (ADR-0002). This is what every screen, the
/// outbox, and the sync engine are built and demoed against until Apple's
/// ID Verifier entitlement is granted (ADR-0006, ROADMAP.md critical path).
///
/// Behavior: [beginVerification] dequeues and returns the next scripted
/// [MockScenario], in order, simulating its latency. Two ways to supply
/// scenarios:
///
/// - [enqueue] — appends one scenario to the live queue. Tests use this to
///   script exact sequences on demand (see test/rails/mock_rail_test.dart).
/// - A fixture loaded via [MockRail.fromFixture] / [MockRail.fromAsset] —
///   seeds the queue from a script and, if [autoLoop] is true, refills from
///   that same script whenever the queue runs dry, so a demo can tap
///   indefinitely without being re-armed by hand.
///
/// Calling [beginVerification] with an empty queue and no fixture to loop
/// from throws [StateError] — a MockRail with nothing scripted is a test
/// setup bug, not a case this class should paper over.
class MockRail implements VerificationRail {
  MockRail({List<MockScenario> initialScript = const [], this.autoLoop = false})
    : _fixtureScript = List.unmodifiable(initialScript),
      _queue = Queue.of(initialScript) {
    checkNotReleaseBuild();
  }

  factory MockRail.fromFixture(
    MockRailFixture fixture, {
    bool autoLoop = true,
  }) => MockRail(initialScript: fixture.script, autoLoop: autoLoop);

  static Future<MockRail> fromAsset(
    String assetKey, {
    AssetBundle? bundle,
    bool autoLoop = true,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(assetKey);
    return MockRail.fromFixture(
      MockRailFixture.fromJsonString(raw),
      autoLoop: autoLoop,
    );
  }

  /// When the queue runs dry, refill it from the fixture this instance was
  /// constructed with, rather than throwing. Production/demo convenience;
  /// tests generally leave this false so an unscripted call is a loud
  /// failure, not a silent repeat of old data.
  final bool autoLoop;

  final List<MockScenario> _fixtureScript;
  final Queue<MockScenario> _queue;
  int _counter = 0;

  /// Test/demo-only: appends [scenario] to the back of the queue. The next
  /// unconsumed [beginVerification] call returns exactly this outcome.
  void enqueue(MockScenario scenario) => _queue.add(scenario);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VerificationOutcome> beginVerification() async {
    if (_queue.isEmpty) {
      if (!autoLoop || _fixtureScript.isEmpty) {
        throw StateError(
          'MockRail has nothing scripted — call enqueue() or construct with '
          'autoLoop: true and a non-empty fixture.',
        );
      }
      _queue.addAll(_fixtureScript);
    }

    final scenario = _queue.removeFirst();
    await Future<void>.delayed(scenario.latency);

    return VerificationOutcome(
      eventId: 'mock_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
      result: scenario.result,
      ageAtLeast21: scenario.ageAtLeast21,
      issuingJurisdiction: scenario.issuingJurisdiction,
      occurredAt: DateTime.now().toUtc(),
      readLatency: scenario.latency,
    );
  }
}
