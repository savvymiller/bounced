// Pigeon schema for the VerificationRail platform channel.
//
// This file is the enforcement mechanism for ADR-0001 and ADR-0003: the
// only data that can cross from the native verification module into Dart
// is what's declared here. No name, no DOB, no portrait, no document
// identifier — enforced by the type system via codegen, not by convention.
//
// Regenerate after editing:
//   dart run pigeon --input pigeons/verification_rail.dart
//
// Adding a field to PigeonVerificationOutcome requires a new ADR
// referenced in the commit message — CI enforces this (PR-24).

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/rails/src/generated/verification_rail_api.g.dart',
    swiftOut: 'ios/Runner/VerificationRailApi.g.swift',
    dartPackageName: 'verifier_app',
  ),
)
class VerificationOutcomeMessage {
  String? eventId;
  RailResultMessage? result;
  bool? ageAtLeast21;
  String? issuingJurisdiction; // state only, e.g. "CA" — never a document ID
  int? occurredAtEpochMs;
  int? readLatencyMs;
}

/// Mirrors the six outcome cases in docs/DATA_MODEL.md's
/// VerificationEvent.railResult. Rail-independent by design (ADR-0007) —
/// these are facts about any age-verification mechanism, not Apple-specific.
enum RailResultMessage {
  approved,
  declined,
  expired,
  unsupportedIssuer,
  readFailed,
  cancelled,
}

@HostApi()
abstract class VerificationRailHostApi {
  /// One call in, one outcome out — deliberately coarse (ADR-0007).
  /// Resist exposing Apple's intermediate sheet states here.
  @async
  VerificationOutcomeMessage beginVerification();

  /// Capability query: can this rail run on this device right now?
  /// (e.g. iPhone XS+ on iOS 17+ — see PR-31.)
  @async
  bool isAvailable();
}
