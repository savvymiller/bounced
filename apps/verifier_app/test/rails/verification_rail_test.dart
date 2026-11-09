import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/verification_outcome.dart';
import 'package:verifier_app/rails/verification_rail.dart';

/// Not MockRail — just enough to prove the interface is coarse enough to
/// implement with its two calls.
class _FakeRail implements VerificationRail {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VerificationOutcome> beginVerification() async => VerificationOutcome(
    eventId: 'evt_fake',
    result: RailResult.approved,
    ageAtLeast21: true,
    issuingJurisdiction: 'CA',
    occurredAt: DateTime.utc(2026),
    readLatency: const Duration(milliseconds: 100),
  );
}

void main() {
  test('VerificationRail is implementable with one capability query and one verification call', () async {
    final VerificationRail rail = _FakeRail();

    expect(await rail.isAvailable(), isTrue);
    final outcome = await rail.beginVerification();
    expect(outcome.result, RailResult.approved);
  });
}
