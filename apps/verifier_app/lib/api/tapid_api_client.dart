import 'dart:convert';

import 'package:http/http.dart' as http;

import '../rails/verification_outcome.dart';
import '../screens/door/human_decision.dart';

/// Reports a verification outcome and the attendant's decision to the demo
/// backend's `POST /v1/events` (services/api/lambda/handler.js). Bearer-auth
/// only — this is a demo client, not the real device-attestation story.
///
/// Fire-and-forget by design: [submitEvent] swallows network/HTTP errors and
/// returns a bool rather than throwing, so a dropped connection never blocks
/// the door screen. This is not the real offline-outbox system described in
/// the project's earlier design docs — just enough to prove outcomes make it
/// to DynamoDB in a demo.
class TapidApiClient {
  TapidApiClient({
    required Uri baseUrl,
    required String bearerToken,
    http.Client? httpClient,
  }) : _eventsUrl = baseUrl.resolve('/v1/events'),
       _authHeader = 'Bearer $bearerToken',
       _client = httpClient ?? http.Client();

  final Uri _eventsUrl;
  final String _authHeader;
  final http.Client _client;

  /// Posts one event. Returns true if the server accepted or recognized it
  /// as a duplicate (both are success from the caller's point of view —
  /// idempotent retries are expected); false on any network error, non-2xx
  /// response, or a server-side `rejected` result.
  Future<bool> submitEvent(
    VerificationOutcome outcome, {
    required HumanDecision decision,
    RefusalReason? reason,
    required String shiftId,
  }) async {
    final body = jsonEncode({
      'events': [
        {
          'eventId': outcome.eventId,
          'railResult': outcome.result.name,
          'ageAtLeast21': outcome.ageAtLeast21,
          'humanDecision': decision.name,
          'refusalReason': reason?.name,
          'issuingJurisdiction': outcome.issuingJurisdiction,
          'occurredAt': outcome.occurredAt.toIso8601String(),
          'shiftId': shiftId,
          'readLatencyMs': outcome.readLatency.inMilliseconds,
          'syncedOffline': false,
        },
      ],
    });

    try {
      final response = await _client.post(
        _eventsUrl,
        headers: {
          'content-type': 'application/json',
          'authorization': _authHeader,
        },
        body: body,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return false;
      final status = (results.first as Map<String, dynamic>)['status'];
      return status == 'accepted' || status == 'duplicate';
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}
