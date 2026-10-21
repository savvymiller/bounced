import '../../rails/verification_outcome.dart';
import 'human_decision.dart';

sealed class DoorScreenState {
  const DoorScreenState();
}

final class Idle extends DoorScreenState {
  const Idle();
}

final class Verifying extends DoorScreenState {
  const Verifying();
}

final class OutcomeReady extends DoorScreenState {
  const OutcomeReady(this.outcome);
  final VerificationOutcome outcome;
}

final class DecisionCaptured extends DoorScreenState {
  const DecisionCaptured({
    required this.outcome,
    required this.decision,
    this.refusalReason,
  });
  final VerificationOutcome outcome;
  final HumanDecision decision;
  final RefusalReason? refusalReason;
}

/// Covers a thrown exception from `beginVerification()` itself — not a
/// scripted outcome (readFailed/cancelled are real RailResult cases, not
/// errors). MockRail only throws on a test-setup mistake, but a future
/// real rail could throw for a genuine hardware/permission failure, so the
/// screen handles it rather than crashing.
final class VerificationFailed extends DoorScreenState {
  const VerificationFailed(this.error);
  final Object error;
}
