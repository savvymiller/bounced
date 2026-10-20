import 'verification_outcome.dart';

/// The seam between the app and whatever actually reads a credential.
///
/// Deliberately coarse (ADR-0007): one async call in, one outcome out, plus
/// a capability query. Two implementations exist from day one — `MockRail`
/// (PR-07) for all pre-entitlement development, and `AppleWalletRail`
/// (PR-30) once Apple approves this project. Adding a third rail (barcode,
/// ISO 18013-5) means implementing this interface and passing the shared
/// contract suite (PR-06) — no changes anywhere else.
abstract class VerificationRail {
  /// Can this rail run on this device right now? (e.g. iPhone XS+ on iOS
  /// 17+ for ProximityReader — see PR-31.) Check before offering the tap
  /// UI at all.
  Future<bool> isAvailable();

  /// Run one verification attempt and return its outcome.
  ///
  /// Resist the temptation to expose intermediate states here (Apple's
  /// tap flow is a single OS-owned modal sheet; a future rail with a
  /// different interaction model should still fit this one call).
  Future<VerificationOutcome> beginVerification();
}
