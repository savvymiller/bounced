import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../rails/verification_outcome.dart';
import '../../rails/verification_rail.dart';
import 'decision_controls.dart';
import 'door_screen_state.dart';
import 'human_decision.dart';
import 'outcome_card.dart';

/// First visible product (docs/DELIVERY_PLAN.md PR-09): one big button,
/// backed by whatever [VerificationRail] the app shell injected —
/// `MockRail` today (ADR-0002), `AppleWalletRail` once PR-30 lands. This
/// screen doesn't know or care which.
class DoorScreen extends StatefulWidget {
  const DoorScreen({super.key});

  @override
  State<DoorScreen> createState() => _DoorScreenState();
}

class _DoorScreenState extends State<DoorScreen> {
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
      icon: const Icon(Icons.wifi, size: 32),
      label: const Text('Tap to Verify'),
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
