import 'package:verifier_app/rails/verification_outcome.dart';

/// A scripted outcome for a [VerificationRailTestHarness] to produce.
///
/// This is the single source of truth for what each of the six outcomes in
/// docs/DATA_MODEL.md's `railResult` enum looks like — the contract suite
/// re-validates that a harness, when told to produce [approved], actually
/// returns an outcome shaped like [approved]. Business rule encoded here:
/// `ageAtLeast21` is only non-null when a credential was actually read and
/// cryptographically age-checked (approved/declined); it's null whenever the
/// rail never got that far. `issuingJurisdiction` follows the same rule,
/// except it's left deliberately unconstrained for `expired` and
/// `unsupportedIssuer` — the docs don't pin down whether the rail learns the
/// state before or after discovering those conditions, so this is modeled
/// as a known gray zone rather than a guessed rule.
class VerificationRailScenario {
  const VerificationRailScenario._({
    required this.result,
    required this.ageAtLeast21,
    required this.issuingJurisdiction,
    required this.latency,
  });

  final RailResult result;
  final bool? ageAtLeast21;
  final String? issuingJurisdiction;
  final Duration latency;

  static const approved = VerificationRailScenario._(
    result: RailResult.approved,
    ageAtLeast21: true,
    issuingJurisdiction: 'CA',
    latency: Duration(milliseconds: 1800),
  );

  static const declined = VerificationRailScenario._(
    result: RailResult.declined,
    ageAtLeast21: false,
    issuingJurisdiction: 'CA',
    latency: Duration(milliseconds: 1800),
  );

  static const expired = VerificationRailScenario._(
    result: RailResult.expired,
    ageAtLeast21: null,
    issuingJurisdiction: 'CA',
    latency: Duration(milliseconds: 1200),
  );

  static const unsupportedIssuer = VerificationRailScenario._(
    result: RailResult.unsupportedIssuer,
    ageAtLeast21: null,
    issuingJurisdiction: 'WY',
    latency: Duration(milliseconds: 900),
  );

  static const readFailed = VerificationRailScenario._(
    result: RailResult.readFailed,
    ageAtLeast21: null,
    issuingJurisdiction: null,
    latency: Duration(milliseconds: 3000),
  );

  static const cancelled = VerificationRailScenario._(
    result: RailResult.cancelled,
    ageAtLeast21: null,
    issuingJurisdiction: null,
    latency: Duration(milliseconds: 600),
  );

  /// Every outcome case — the contract suite iterates this to guarantee no
  /// case is silently skipped.
  static const all = [
    approved,
    declined,
    expired,
    unsupportedIssuer,
    readFailed,
    cancelled,
  ];
}
