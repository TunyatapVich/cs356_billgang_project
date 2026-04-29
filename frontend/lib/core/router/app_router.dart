import 'package:go_router/go_router.dart';

// TODO: import screens as they are built

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // auth
    GoRoute(path: '/login', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/register', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/profile-setup', builder: (_, __) => const Placeholder()),

    // main
    GoRoute(path: '/home', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/create', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/items', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/ocr', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/invite', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/assign', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bill/:id/settlement', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/join', builder: (_, __) => const Placeholder()),
  ],
);
