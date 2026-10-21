import 'package:go_router/go_router.dart';

import '../screens/home/home_placeholder_screen.dart';

/// One route today — [HomePlaceholderScreen], standing in for the real door
/// screen (PR-09). Using go_router from the start, even with a single
/// route, so later screens (shift claim, settings, history) are additive
/// route entries rather than a routing-framework migration.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
    ],
  );
}
