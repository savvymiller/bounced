import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/screens/door/decision_controls.dart';
import 'package:verifier_app/screens/door/human_decision.dart';

void main() {
  testWidgets('tapping Allow entry fires onDecision(allowed, null)', (
    tester,
  ) async {
    HumanDecision? decision;
    RefusalReason? reason;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DecisionControls(
            onDecision: (d, r) {
              decision = d;
              reason = r;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Allow entry'));
    await tester.pump();

    expect(decision, HumanDecision.allowed);
    expect(reason, isNull);
  });

  testWidgets(
    'Refuse entry reveals a reason picker; Confirm is disabled until a reason is chosen',
    (tester) async {
      HumanDecision? decision;
      RefusalReason? reason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DecisionControls(
              onDecision: (d, r) {
                decision = d;
                reason = r;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Refuse entry'));
      await tester.pump();

      expect(find.text('Reason for refusal'), findsOneWidget);
      final confirmButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm refusal'),
      );
      expect(confirmButton.onPressed, isNull);

      await tester.tap(find.text('Underage'));
      await tester.pump();

      await tester.tap(find.text('Confirm refusal'));
      await tester.pump();

      expect(decision, HumanDecision.refused);
      expect(reason, RefusalReason.underage);
    },
  );
}
