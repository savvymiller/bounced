import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/tapid_api_client.dart';
import '../rails/verification_rail.dart';
import '../theming/app_theme.dart';
import 'app_router.dart';

/// The composition root's widget: wires dependency injection ([rail],
/// [apiClient]), routing, and theming. No feature screens live here.
///
/// [apiClient] is nullable because it's only constructed when
/// `--dart-define`s for the backend are supplied (see `main.dart`) — the
/// app still works as a scan-only demo without one, it just doesn't report
/// outcomes anywhere.
class AppShell extends StatelessWidget {
  AppShell({
    super.key,
    required this.rail,
    this.apiClient,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : _router = buildAppRouter(navigatorKey: navigatorKey);

  final VerificationRail rail;
  final TapidApiClient? apiClient;
  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VerificationRail>.value(value: rail),
        Provider<TapidApiClient?>.value(value: apiClient),
      ],
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
