// Proves the shared contract suite (test/support/verification_rail_contract.dart)
// is itself runnable and correct, ahead of PR-07's MockRail — per ADR-0002,
// the suite is written before any implementation exists.
//
// `_StubRail` below is throwaway scaffolding for this file only. It is not
// MockRail: it has no fixture file, no release-build compile guard, and
// must never be used outside this test.

import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/verification_outcome.dart';
import 'package:verifier_app/rails/verification_rail.dart';

import '../support/verification_rail_contract.dart';
import '../support/verification_rail_harness.dart';
import '../support/verification_rail_scenario.dart';

class _StubRail implements VerificationRail {
  final Queue<VerificationRailScenario> _queue = Queue();
  int _counter = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VerificationOutcome> beginVerification() async {
    if (_queue.isEmpty) {
      throw StateError(
        'No scenario scripted — call scriptNext before beginVerification.',
      );
    }
    final scenario = _queue.removeFirst();
    await Future<void>.delayed(scenario.latency);
    return VerificationOutcome(
      eventId: 'stub_evt_${_counter++}',
      result: scenario.result,
      ageAtLeast21: scenario.ageAtLeast21,
      issuingJurisdiction: scenario.issuingJurisdiction,
      occurredAt: DateTime.now().toUtc(),
      readLatency: scenario.latency,
    );
  }
}

class _StubHarness implements VerificationRailTestHarness {
  _StubHarness() : rail = _StubRail();

  @override
  final _StubRail rail;

  @override
  Future<void> scriptNext(VerificationRailScenario scenario) async {
    rail._queue.add(scenario);
  }
}

void main() {
  runVerificationRailContractTests(() => _StubHarness());
}
