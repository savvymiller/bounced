import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/mock_scenario.dart';
import 'package:verifier_app/rails/verification_outcome.dart';

void main() {
  group('MockRailFixture.fromJsonString', () {
    test('parses a well-formed fixture', () {
      final fixture = MockRailFixture.fromJsonString('''
      {
        "script": [
          { "result": "approved", "ageAtLeast21": true, "issuingJurisdiction": "CA", "latencyMs": 1800 },
          { "result": "readFailed", "ageAtLeast21": null, "issuingJurisdiction": null, "latencyMs": 3000 }
        ]
      }
      ''');

      expect(fixture.script, hasLength(2));
      expect(fixture.script[0].result, RailResult.approved);
      expect(fixture.script[0].ageAtLeast21, isTrue);
      expect(fixture.script[0].issuingJurisdiction, 'CA');
      expect(fixture.script[0].latency, const Duration(milliseconds: 1800));
      expect(fixture.script[1].result, RailResult.readFailed);
      expect(fixture.script[1].ageAtLeast21, isNull);
    });

    test('rejects an unknown result name with a clear message', () {
      expect(
        () => MockRailFixture.fromJsonString(
          '{"script": [{"result": "approvd", "latencyMs": 100}]}',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('is not a RailResult'),
          ),
        ),
      );
    });

    test('rejects a missing "script" key', () {
      expect(
        () => MockRailFixture.fromJsonString('{"foo": []}'),
        throwsFormatException,
      );
    });

    test('rejects a non-int latencyMs', () {
      expect(
        () => MockRailFixture.fromJsonString(
          '{"script": [{"result": "approved", "latencyMs": "fast"}]}',
        ),
        throwsFormatException,
      );
    });
  });

  test('the shipped default fixture asset itself parses cleanly', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString(
      'assets/fixtures/mock_rail_default.json',
    );
    final fixture = MockRailFixture.fromJsonString(raw);

    expect(fixture.script, isNotEmpty);
    // Every outcome case should appear at least once in the demo script —
    // a fixture that only ever approves is a bad demo, not a real check,
    // but worth guarding since it's hand-edited JSON.
    final coveredResults = fixture.script.map((s) => s.result).toSet();
    expect(coveredResults, RailResult.values.toSet());
  });
}
