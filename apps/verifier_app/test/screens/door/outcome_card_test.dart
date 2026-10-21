import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/verification_outcome.dart';
import 'package:verifier_app/screens/door/outcome_card.dart';

VerificationOutcome _outcome({
  required RailResult result,
  bool? ageAtLeast21,
  String? issuingJurisdiction,
  Duration readLatency = const Duration(milliseconds: 1234),
}) {
  return VerificationOutcome(
    eventId: 'evt',
    result: result,
    ageAtLeast21: ageAtLeast21,
    issuingJurisdiction: issuingJurisdiction,
    occurredAt: DateTime.utc(2026),
    readLatency: readLatency,
  );
}

Future<void> _pump(WidgetTester tester, VerificationOutcome outcome) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: OutcomeCard(outcome: outcome)),
    ),
  );
}

void main() {
  final cases = <RailResult, String>{
    RailResult.approved: 'Approved — 21 or older',
    RailResult.declined: 'Declined — under 21',
    RailResult.expired: 'Credential expired',
    RailResult.unsupportedIssuer: 'Unsupported issuer',
    RailResult.readFailed: 'Read failed',
    RailResult.cancelled: 'Cancelled',
  };

  for (final entry in cases.entries) {
    testWidgets('renders the correct label for ${entry.key.name}', (
      tester,
    ) async {
      await _pump(tester, _outcome(result: entry.key));
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('shows issuingJurisdiction when present', (tester) async {
    await _pump(
      tester,
      _outcome(result: RailResult.approved, issuingJurisdiction: 'CA'),
    );
    expect(find.text('Issued by: CA'), findsOneWidget);
  });

  testWidgets('omits the jurisdiction line when null', (tester) async {
    await _pump(tester, _outcome(result: RailResult.readFailed));
    expect(find.textContaining('Issued by:'), findsNothing);
  });

  testWidgets('shows the read latency in milliseconds', (tester) async {
    await _pump(
      tester,
      _outcome(
        result: RailResult.approved,
        readLatency: const Duration(milliseconds: 1800),
      ),
    );
    expect(find.text('Read in 1800ms'), findsOneWidget);
  });
}
