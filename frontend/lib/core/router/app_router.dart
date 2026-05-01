import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    // GoRoute(path: '/register', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/profile-setup', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/home', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/bill/create', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/bill/:id/items', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/bill/:id/ocr', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/bill/:id/invite', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/bill/:id/assign', builder: (_, __) => const Placeholder()),
    // GoRoute(
    // path: '/bill/:id/settlement',
    // builder: (_, __) => const Placeholder(),
    // ),
    // GoRoute(path: '/join', builder: (_, __) => const Placeholder()),
  ],
);
