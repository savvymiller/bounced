import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verifier_app/rails/mock_rail.dart';
import 'package:verifier_app/rails/mock_scenario.dart';
import 'package:verifier_app/rails/verification_outcome.dart';
import 'package:verifier_app/rails/verification_rail.dart';
import 'package:verifier_app/screens/door/door_screen.dart';

Widget _wrap(VerificationRail rail) {
  return Provider<VerificationRail>.value(
    value: rail,
    child: const MaterialApp(home: DoorScreen()),
  );
}

void main() {
  testWidgets(
    'full flow: tap -> outcome -> allow -> next patron resets to idle',
    (tester) async {
      final rail = MockRail();
      rail.enqueue(
        const MockScenario(
          result: RailResult.approved,
          ageAtLeast21: true,
          issuingJurisdiction: 'CA',
          latency: Duration.zero,
        ),
      );

      await tester.pumpWidget(_wrap(rail));
      expect(find.text('Tap to Verify'), findsOneWidget);

      await tester.tap(find.text('Tap to Verify'));
      await tester.pump();
      expect(find.text('Verifying…'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Approved — 21 or older'), findsOneWidget);
      expect(find.text('Allow entry'), findsOneWidget);

      await tester.tap(find.text('Allow entry'));
      await tester.pump();

      expect(find.text('Allowed entry'), findsOneWidget);
      expect(find.text('Next patron'), findsOneWidget);

      await tester.tap(find.text('Next patron'));
      await tester.pump();

      expect(find.text('Tap to Verify'), findsOneWidget);
    },
  );

  testWidgets('refuse flow records the chosen reason in the summary', (
    tester,
  ) async {
    final rail = MockRail();
    rail.enqueue(
      const MockScenario(
        result: RailResult.declined,
        ageAtLeast21: false,
        issuingJurisdiction: 'CA',
        latency: Duration.zero,
      ),
    );

    await tester.pumpWidget(_wrap(rail));
    await tester.tap(find.text('Tap to Verify'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuse entry'));
    await tester.pump();
    await tester.tap(find.text('Underage'));
    await tester.pump();
    await tester.tap(find.text('Confirm refusal'));
    await tester.pump();

    expect(find.text('Refused entry — Underage'), findsOneWidget);
  });

  testWidgets('a thrown error surfaces a retry screen instead of crashing', (
    tester,
  ) async {
    final rail = MockRail(); // nothing scripted, autoLoop false -> beginVerification() throws

    await tester.pumpWidget(_wrap(rail));
    await tester.tap(find.text('Tap to Verify'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Verification failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Tap to Verify'), findsOneWidget);
  });
}
