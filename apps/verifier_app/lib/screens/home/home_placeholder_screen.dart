import 'package:flutter/material.dart';

/// Stands in for the real door screen until PR-09. Deliberately not a
/// "feature" — this PR is shell only (DI, routing, theming, result types,
/// logging), per docs/DELIVERY_PLAN.md's PR-08 scope.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TapID')),
      body: const Center(child: Text('Door screen lands in PR-09.')),
    );
  }
}
