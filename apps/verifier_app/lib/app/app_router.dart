import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/door/door_screen.dart';

/// One route today — [DoorScreen]. Using go_router from the start, even
/// with a single route, so later screens (shift claim, settings, history)
/// are additive route entries rather than a routing-framework migration.
///
/// [navigatorKey] is exposed so [Pdf417Rail.live] can push its full-screen
/// camera UI onto the same root navigator go_router manages, without the
/// door screen or router needing a route for it.
GoRouter buildAppRouter({GlobalKey<NavigatorState>? navigatorKey}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'door',
        builder: (context, state) => const DoorScreen(),
      ),
    ],
  );
}
