import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verifier_app/api/tapid_api_client.dart';
import 'package:verifier_app/rails/verification_outcome.dart';
import 'package:verifier_app/screens/door/human_decision.dart';

final _outcome = VerificationOutcome(
  eventId: 'evt_01H8X',
  result: RailResult.approved,
  ageAtLeast21: true,
  issuingJurisdiction: 'CA',
  occurredAt: DateTime.utc(2026, 7, 29, 4, 12, 33),
  readLatency: const Duration(milliseconds: 1800),
);

void main() {
  test('submitEvent POSTs the expected shape and headers', () async {
    http.Request? captured;
    final client = TapidApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      bearerToken: 'secret-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'results': [
              {'eventId': 'evt_01H8X', 'status': 'accepted'},
            ],
          }),
          200,
        );
      }),
    );

    final accepted = await client.submitEvent(
      _outcome,
      decision: HumanDecision.allowed,
      reason: null,
      shiftId: 'sft_demo',
    );

    expect(accepted, isTrue);
    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url, Uri.parse('https://api.example.com/v1/events'));
    expect(captured!.headers['authorization'], 'Bearer secret-token');
    expect(captured!.headers['content-type'], 'application/json');

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final event = (body['events'] as List).single as Map<String, dynamic>;
    expect(event['eventId'], 'evt_01H8X');
    expect(event['railResult'], 'approved');
    expect(event['ageAtLeast21'], isTrue);
    expect(event['humanDecision'], 'allowed');
    expect(event['refusalReason'], isNull);
    expect(event['issuingJurisdiction'], 'CA');
    expect(event['shiftId'], 'sft_demo');
    expect(event['readLatencyMs'], 1800);
    expect(event['syncedOffline'], isFalse);
  });

  test('a refusal reason is included when present', () async {
    final client = TapidApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      bearerToken: 'secret-token',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final event = (body['events'] as List).single as Map<String, dynamic>;
        expect(event['humanDecision'], 'refused');
        expect(event['refusalReason'], 'underage');
        return http.Response(
          jsonEncode({
            'results': [
              {'eventId': 'evt_01H8X', 'status': 'accepted'},
            ],
          }),
          200,
        );
      }),
    );

    final accepted = await client.submitEvent(
      _outcome,
      decision: HumanDecision.refused,
      reason: RefusalReason.underage,
      shiftId: 'sft_demo',
    );

    expect(accepted, isTrue);
  });

  test('a duplicate result still counts as accepted', () async {
    final client = TapidApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      bearerToken: 'secret-token',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'results': [
              {'eventId': 'evt_01H8X', 'status': 'duplicate'},
            ],
          }),
          200,
        ),
      ),
    );

    final accepted = await client.submitEvent(
      _outcome,
      decision: HumanDecision.allowed,
      reason: null,
      shiftId: 'sft_demo',
    );

    expect(accepted, isTrue);
  });

  test('a rejected result is reported as not accepted', () async {
    final client = TapidApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      bearerToken: 'secret-token',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'results': [
              {'eventId': 'evt_01H8X', 'status': 'rejected'},
            ],
          }),
          200,
        ),
      ),
    );

    final accepted = await client.submitEvent(
      _outcome,
      decision: HumanDecision.allowed,
      reason: null,
      shiftId: 'sft_demo',
    );

    expect(accepted, isFalse);
  });

  test('a non-2xx response is reported as not accepted', () async {
    final client = TapidApiClient(
      baseUrl: Uri.parse('https://api.example.com'),
      bearerToken: 'secret-token',
      httpClient: MockClient(
        (request) async => http.Response('unauthorized', 401),
      ),
    );

    final accepted = await client.submitEvent(
      _outcome,
      decision: HumanDecision.allowed,
      reason: null,
      shiftId: 'sft_demo',
    );

    expect(accepted, isFalse);
  });

  test(
    'a thrown network error is reported as not accepted, not rethrown',
    () async {
      final client = TapidApiClient(
        baseUrl: Uri.parse('https://api.example.com'),
        bearerToken: 'secret-token',
        httpClient: MockClient((request) async {
          throw const SocketExceptionStub();
        }),
      );

      final accepted = await client.submitEvent(
        _outcome,
        decision: HumanDecision.allowed,
        reason: null,
        shiftId: 'sft_demo',
      );

      expect(accepted, isFalse);
    },
  );
}

/// A throwaway stand-in for `dart:io`'s `SocketException` — avoids pulling
/// in `dart:io` just to prove `submitEvent` swallows arbitrary exceptions.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
