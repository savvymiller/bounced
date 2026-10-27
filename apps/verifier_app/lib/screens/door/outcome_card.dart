import 'package:flutter/material.dart';

import '../../rails/verification_outcome.dart';

/// Pure presentational — summarizes one tap's result. Color/icon/label are
/// keyed off [RailResult] only; this card has no idea whether it's looking
/// at a mock tap or a real one.
class OutcomeCard extends StatelessWidget {
  const OutcomeCard({super.key, required this.outcome});

  final VerificationOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(outcome.result);
    return Card(
      color: style.color.withAlpha(30),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: style.color, size: 48),
            const SizedBox(height: 12),
            Text(
              style.label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: style.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (outcome.issuingJurisdiction != null) ...[
              const SizedBox(height: 4),
              Text('Issued by: ${outcome.issuingJurisdiction}'),
            ],
            const SizedBox(height: 4),
            Text(
              'Read in ${outcome.readLatency.inMilliseconds}ms',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  _OutcomeStyle _styleFor(RailResult result) => switch (result) {
    RailResult.approved => const _OutcomeStyle(
      Icons.check_circle,
      Colors.green,
      'Approved — 21 or older',
    ),
    RailResult.declined => const _OutcomeStyle(
      Icons.cancel,
      Colors.red,
      'Declined — under 21',
    ),
    RailResult.expired => const _OutcomeStyle(
      Icons.event_busy,
      Colors.orange,
      'Credential expired',
    ),
    RailResult.unsupportedIssuer => const _OutcomeStyle(
      Icons.help_outline,
      Colors.orange,
      'Unsupported issuer',
    ),
    RailResult.readFailed => const _OutcomeStyle(
      Icons.error_outline,
      Colors.grey,
      'Read failed',
    ),
    RailResult.cancelled => const _OutcomeStyle(
      Icons.block,
      Colors.grey,
      'Cancelled',
    ),
  };
}

class _OutcomeStyle {
  const _OutcomeStyle(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}
