import 'verification_outcome.dart';

/// The seam between the app and whatever actually reads a credential.
///
/// Deliberately coarse: one async call in, one outcome out, plus a
/// capability query. `MockRail` backs tests; `Pdf417Rail` is the real
/// production rail. Adding another rail means implementing this interface
/// and passing the shared contract suite
/// (test/support/verification_rail_contract.dart) — no changes anywhere
/// else.
abstract class VerificationRail {
  /// Can this rail run on this device right now? Check before offering the
  /// scan UI at all.
  Future<bool> isAvailable();

  /// Run one verification attempt and return its outcome.
  ///
  /// Resist the temptation to expose intermediate states here — a rail with
  /// a different interaction model should still fit this one call.
  Future<VerificationOutcome> beginVerification();
}
