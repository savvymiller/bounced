import 'package:flutter/material.dart';

import 'human_decision.dart';

/// Allow/Refuse — the attendant's own call, captured independently of the
/// rail's result (see human_decision.dart). Refuse reveals a small,
/// fixed-choice reason picker; the decision isn't considered final until
/// [onDecision] fires.
class DecisionControls extends StatefulWidget {
  const DecisionControls({super.key, required this.onDecision});

  final void Function(HumanDecision decision, RefusalReason? reason) onDecision;

  @override
  State<DecisionControls> createState() => _DecisionControlsState();
}

class _DecisionControlsState extends State<DecisionControls> {
  bool _showReasonPicker = false;
  RefusalReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    if (_showReasonPicker) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Reason for refusal'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final reason in RefusalReason.values)
                ChoiceChip(
                  label: Text(reason.label),
                  selected: _selectedReason == reason,
                  onSelected: (_) => setState(() => _selectedReason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedReason == null
                ? null
                : () =>
                      widget.onDecision(HumanDecision.refused, _selectedReason),
            child: const Text('Confirm refusal'),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => widget.onDecision(HumanDecision.allowed, null),
          child: const Text('Allow entry'),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () => setState(() => _showReasonPicker = true),
          child: const Text('Refuse entry'),
        ),
      ],
    );
  }
}
