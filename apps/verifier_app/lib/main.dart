import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'rails/pdf417_rail.dart';

/// The composition root. `Pdf417Rail` is the production rail — it reads the
/// barcode on the back of a physical ID via the device camera, needing no
/// Apple entitlement. `MockRail` remains available for widget tests and the
/// contract suite; it is no longer constructed here.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final navigatorKey = GlobalKey<NavigatorState>();
  final rail = Pdf417Rail.live(navigatorKey: navigatorKey);
  runApp(AppShell(rail: rail, navigatorKey: navigatorKey));
}
