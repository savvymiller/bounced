import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/screens/door/human_decision.dart';

void main() {
  test('every RefusalReason has a human-readable label', () {
    expect(RefusalReason.underage.label, 'Underage');
    expect(RefusalReason.suspiciousId.label, 'Suspicious ID');
    expect(RefusalReason.other.label, 'Other');
  });
}
