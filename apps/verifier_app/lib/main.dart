import 'package:flutter/material.dart';

/// Placeholder entrypoint. PR-08 adds the real app shell (DI, routing,
/// theming) — this file deliberately has nothing to do with the
/// verification rail added in this PR.
void main() {
  runApp(const _Placeholder());
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => const MaterialApp(home: Scaffold());
}
