import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/pdf417_rail.dart';
import 'package:verifier_app/rails/verification_outcome.dart';

import '../support/verification_rail_contract.dart';
import '../support/verification_rail_harness.dart';
import '../support/verification_rail_scenario.dart' as contract;

/// Fixed so age-at-21 math is deterministic, independent of the day the
/// test actually runs.
final _fixedNow = DateTime.utc(2026, 1, 1);

String _rawFor({required String iin, String? dob, String? expiration}) {
  final buffer = StringBuffer('@\n\x1e\rANSI ${iin}0902DL00410278ZV03190008DL');
  if (dob != null) buffer.write('DBB$dob');
  if (expiration != null) buffer.write('DBA$expiration');
  return buffer.toString();
}

/// Scripts [Pdf417Rail] by queuing raw barcode payloads (or `null`, for a
/// cancelled scan) that produce each [contract.VerificationRailScenario]'s
/// outcome once decoded — the barcode-rail analogue of how
/// `_MockRailHarness` scripts `MockRail` directly.
class _Pdf417RailHarness implements VerificationRailTestHarness {
  _Pdf417RailHarness() {
    rail = Pdf417Rail(scan: () => _queue.removeFirst()(), now: () => _fixedNow);
  }

  @override
  late final Pdf417Rail rail;

  final Queue<Future<String?> Function()> _queue = Queue();

  @override
  Future<void> scriptNext(contract.VerificationRailScenario scenario) async {
    _queue.add(() => _produce(scenario));
  }

  Future<String?> _produce(contract.VerificationRailScenario scenario) async {
    await Future<void>.delayed(scenario.latency);
    return switch (scenario.result) {
      RailResult.cancelled => null,
      RailResult.readFailed => 'not a barcode at all',
      RailResult.unsupportedIssuer => _rawFor(iin: '636012'), // Ontario
      RailResult.expired => _rawFor(
        iin: '636014',
        dob: '01011970',
        expiration: '01012020', // before _fixedNow
      ),
      RailResult.approved => _rawFor(
        iin: '636014',
        dob: '01011990', // 36 as of _fixedNow
        expiration: '01012030',
      ),
      RailResult.declined => _rawFor(
        iin: '636014',
        dob: '01012010', // 16 as of _fixedNow
        expiration: '01012030',
      ),
    };
  }
}

void main() {
  runVerificationRailContractTests(() => _Pdf417RailHarness());
}
