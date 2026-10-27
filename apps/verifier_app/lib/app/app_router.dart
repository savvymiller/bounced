import 'package:go_router/go_router.dart';

import '../screens/door/door_screen.dart';

/// One route today — [DoorScreen]. Using go_router from the start, even
/// with a single route, so later screens (shift claim, settings, history)
/// are additive route entries rather than a routing-framework migration.
GoRouter buildAppRouter() {
  return GoRouter(
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
