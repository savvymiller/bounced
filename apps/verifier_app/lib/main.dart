import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'rails/mock_rail.dart';

/// The composition root. MockRail is the only VerificationRail that exists
/// today (ADR-0002) — AppleWalletRail arrives in PR-30, gated on Apple's
/// entitlement. Which rail gets constructed here is expected to become a
/// build-time/config decision once that exists; for now there is only one
/// real choice to make.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final rail = await MockRail.fromAsset(
    'assets/fixtures/mock_rail_default.json',
  );
  runApp(AppShell(rail: rail));
}
