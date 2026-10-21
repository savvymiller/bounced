import 'dart:convert';

import 'verification_outcome.dart';

/// One scripted outcome in a [MockRailFixture].
///
/// Deliberately independent from `test/support/verification_rail_scenario.dart`,
/// even though the shapes overlap — that file is test-only (QA/demo scripting
/// here is production-facing, loaded from a JSON asset a non-engineer might
/// edit) and lib code must never depend on anything under test/.
class MockScenario {
  const MockScenario({
    required this.result,
    required this.ageAtLeast21,
    required this.issuingJurisdiction,
    required this.latency,
  });

  final RailResult result;
  final bool? ageAtLeast21;
  final String? issuingJurisdiction;
  final Duration latency;

  factory MockScenario.fromJson(
    Map<String, dynamic> json, {
    required int index,
  }) {
    final resultName = json['result'];
    if (resultName is! String) {
      throw FormatException(
        'fixture entry $index: "result" must be a string, got $resultName',
      );
    }
    RailResult? result;
    for (final candidate in RailResult.values) {
      if (candidate.name == resultName) {
        result = candidate;
        break;
      }
    }
    if (result == null) {
      final valid = RailResult.values.map((r) => r.name).join(', ');
      throw FormatException(
        'fixture entry $index: "$resultName" is not a RailResult (expected one of: $valid)',
      );
    }

    final ageAtLeast21 = json['ageAtLeast21'];
    if (ageAtLeast21 != null && ageAtLeast21 is! bool) {
      throw FormatException(
        'fixture entry $index: "ageAtLeast21" must be a bool or null',
      );
    }

    final issuingJurisdiction = json['issuingJurisdiction'];
    if (issuingJurisdiction != null && issuingJurisdiction is! String) {
      throw FormatException(
        'fixture entry $index: "issuingJurisdiction" must be a string or null',
      );
    }

    final latencyMs = json['latencyMs'];
    if (latencyMs is! int) {
      throw FormatException(
        'fixture entry $index: "latencyMs" must be an int, got $latencyMs',
      );
    }

    return MockScenario(
      result: result,
      ageAtLeast21: ageAtLeast21 as bool?,
      issuingJurisdiction: issuingJurisdiction as String?,
      latency: Duration(milliseconds: latencyMs),
    );
  }
}

/// A named, ordered script of [MockScenario]s — what ADR-0002 calls a
/// "fixture file", meant to be hand-editable by QA/demos without touching
/// Dart.
class MockRailFixture {
  const MockRailFixture(this.script);

  final List<MockScenario> script;

  factory MockRailFixture.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['script'] is! List) {
      throw const FormatException(
        'fixture must be a JSON object with a "script" array',
      );
    }
    final entries = decoded['script'] as List;
    return MockRailFixture([
      for (var i = 0; i < entries.length; i++)
        MockScenario.fromJson(entries[i] as Map<String, dynamic>, index: i),
    ]);
  }
}
