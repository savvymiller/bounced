import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:verifier_app/api/tapid_api_client.dart';
import 'package:verifier_app/rails/mock_rail.dart';
import 'package:verifier_app/rails/mock_scenario.dart';
import 'package:verifier_app/rails/verification_outcome.dart';
import 'package:verifier_app/rails/verification_rail.dart';
import 'package:verifier_app/screens/door/door_screen.dart';

Widget _wrap(VerificationRail rail, {TapidApiClient? apiClient}) {
  return MultiProvider(
    providers: [
      Provider<VerificationRail>.value(value: rail),
      // No backend configured by default — DoorScreen must treat this as
      // a no-op, not a missing-provider crash.
      Provider<TapidApiClient?>.value(value: apiClient),
    ],
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
      expect(find.text('Scan ID'), findsOneWidget);

      await tester.tap(find.text('Scan ID'));
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

      expect(find.text('Scan ID'), findsOneWidget);
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
    await tester.tap(find.text('Scan ID'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuse entry'));
    await tester.pump();
    await tester.tap(find.text('Underage'));
    await tester.pump();
    await tester.tap(find.text('Confirm refusal'));
    await tester.pump();

    expect(find.text('Refused entry — Underage'), findsOneWidget);
  });

  testWidgets('reports the decision to the API client when one is configured', (
    tester,
  ) async {
    http.Request? captured;
    final apiClient = TapidApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      bearerToken: 'secret-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('{"results":[{"status":"accepted"}]}', 200);
      }),
    );

    final rail = MockRail();
    rail.enqueue(
      const MockScenario(
        result: RailResult.approved,
        ageAtLeast21: true,
        issuingJurisdiction: 'CA',
        latency: Duration.zero,
      ),
    );

    await tester.pumpWidget(_wrap(rail, apiClient: apiClient));
    await tester.tap(find.text('Scan ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow entry'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.url.path, '/v1/events');
  });

  testWidgets('a thrown error surfaces a retry screen instead of crashing', (
    tester,
  ) async {
    final rail = MockRail(); // nothing scripted, autoLoop false -> beginVerification() throws

    await tester.pumpWidget(_wrap(rail));
    await tester.tap(find.text('Scan ID'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Verification failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Scan ID'), findsOneWidget);
  });
}
