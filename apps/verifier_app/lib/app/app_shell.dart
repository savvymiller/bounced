import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../rails/verification_rail.dart';
import '../theming/app_theme.dart';
import 'app_router.dart';

/// The composition root's widget: wires dependency injection (today, just
/// the [VerificationRail] — more arrive as later PRs add an API client,
/// local storage, etc.), routing, and theming. No feature screens live
/// here; see docs/DELIVERY_PLAN.md's PR-08 scope.
class AppShell extends StatelessWidget {
  AppShell({super.key, required this.rail}) : _router = buildAppRouter();

  final VerificationRail rail;
  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return Provider<VerificationRail>.value(
      value: rail,
      child: MaterialApp.router(
        title: 'TapID',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
