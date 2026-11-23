import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/tapid_api_client.dart';
import '../../common/app_logger.dart';
import '../../rails/verification_outcome.dart';
import '../../rails/verification_rail.dart';
import 'decision_controls.dart';
import 'door_screen_state.dart';
import 'human_decision.dart';
import 'outcome_card.dart';

/// Stand-in for a real shift-claim flow — there's no staff-login screen yet
/// (`POST /v1/shifts` exists on the backend but nothing in the app calls
/// it), so every event is attributed to this fixed placeholder.
const _placeholderShiftId = 'sft_demo';

/// One big button, backed by whatever [VerificationRail] the app shell
/// injected — `Pdf417Rail` in production, `MockRail` in tests. This screen
/// doesn't know or care which.
class DoorScreen extends StatefulWidget {
  const DoorScreen({super.key});

  @override
  State<DoorScreen> createState() => _DoorScreenState();
}

class _DoorScreenState extends State<DoorScreen> {
  static const _log = AppLogger('door_screen');

  DoorScreenState _state = const Idle();

  Future<void> _beginVerification() async {
    final rail = context.read<VerificationRail>();
    setState(() => _state = const Verifying());

    try {
      final outcome = await rail.beginVerification();
      if (!mounted) return;
      setState(() => _state = OutcomeReady(outcome));
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = VerificationFailed(error));
    }
  }

  void _captureDecision(
    VerificationOutcome outcome,
    HumanDecision decision,
    RefusalReason? reason,
  ) {
    setState(
      () => _state = DecisionCaptured(
        outcome: outcome,
        decision: decision,
        refusalReason: reason,
      ),
    );
    _reportDecision(outcome, decision, reason);
  }

  /// Best-effort: a dropped connection or backend error never blocks the
  /// door screen, which has already moved on by the time this resolves.
  /// Not the real offline-outbox story — just enough to prove outcomes
  /// reach the backend in a demo. No-ops entirely if no [TapidApiClient]
  /// was configured (see `main.dart`).
  Future<void> _reportDecision(
    VerificationOutcome outcome,
    HumanDecision decision,
    RefusalReason? reason,
  ) async {
    final client = context.read<TapidApiClient?>();
    if (client == null) return;

    final accepted = await client.submitEvent(
      outcome,
      decision: decision,
      reason: reason,
      shiftId: _placeholderShiftId,
    );
    if (!accepted) {
      _log.warn(
        'event submission failed',
        fields: {'eventId': outcome.eventId},
      );
    }
  }

  void _reset() => setState(() => _state = const Idle());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Door')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_state) {
            Idle() => _buildIdle(),
            Verifying() => _buildVerifying(),
            OutcomeReady(outcome: final outcome) => _buildOutcomeReady(outcome),
            DecisionCaptured(
              outcome: final outcome,
              decision: final decision,
              refusalReason: final reason,
            ) =>
              _buildDecisionCaptured(outcome, decision, reason),
            VerificationFailed(error: final error) => _buildFailed(error),
          },
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return ElevatedButton.icon(
      onPressed: _beginVerification,
      icon: const Icon(Icons.qr_code_scanner, size: 32),
      label: const Text('Scan ID'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        textStyle: const TextStyle(fontSize: 24),
      ),
    );
  }

  Widget _buildVerifying() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Verifying…', style: TextStyle(fontSize: 20)),
      ],
    );
  }

  Widget _buildOutcomeReady(VerificationOutcome outcome) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutcomeCard(outcome: outcome),
        const SizedBox(height: 24),
        DecisionControls(
          onDecision: (decision, reason) =>
              _captureDecision(outcome, decision, reason),
        ),
      ],
    );
  }

  Widget _buildDecisionCaptured(
    VerificationOutcome outcome,
    HumanDecision decision,
    RefusalReason? reason,
  ) {
    final label = switch (decision) {
      HumanDecision.allowed => 'Allowed entry',
      HumanDecision.refused =>
        'Refused entry${reason != null ? ' — ${reason.label}' : ''}',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutcomeCard(outcome: outcome),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _reset, child: const Text('Next patron')),
      ],
    );
  }

  Widget _buildFailed(Object error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text('Verification failed: $error', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _reset, child: const Text('Retry')),
      ],
    );
  }
}
