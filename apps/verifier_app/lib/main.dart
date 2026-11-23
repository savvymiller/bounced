import 'package:flutter/material.dart';

import 'api/tapid_api_client.dart';
import 'app/app_shell.dart';
import 'rails/pdf417_rail.dart';

/// Backend connection details, supplied at build/run time via
/// `--dart-define=API_BASE_URL=... --dart-define=API_BEARER_TOKEN=...`.
/// Never hardcoded, never committed. Both must be non-empty for the app to
/// report outcomes anywhere — see `TapidApiClient`'s doc comment.
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _apiBearerToken = String.fromEnvironment('API_BEARER_TOKEN');

/// The composition root. `Pdf417Rail` is the production rail — it reads the
/// barcode on the back of a physical ID via the device camera, needing no
/// Apple entitlement. `MockRail` remains available for widget tests and the
/// contract suite; it is no longer constructed here.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final navigatorKey = GlobalKey<NavigatorState>();
  final rail = Pdf417Rail.live(navigatorKey: navigatorKey);

  final apiClient = _apiBaseUrl.isNotEmpty && _apiBearerToken.isNotEmpty
      ? TapidApiClient(
          baseUrl: Uri.parse(_apiBaseUrl),
          bearerToken: _apiBearerToken,
        )
      : null;

  runApp(
    AppShell(rail: rail, apiClient: apiClient, navigatorKey: navigatorKey),
  );
}
