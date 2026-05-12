import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/bill/create_bill_screen.dart';
import '../../features/bill/add_items_screen.dart';
import '../../features/bill/ocr_review_screen.dart';
import '../../features/bill/bill_summary_screen.dart';
import '../../features/bill/edit_bill_screen.dart';
import '../../features/assign/assign_screen.dart';
import '../../features/invite/invite_screen.dart';
import '../../features/invite/join_screen.dart';
import '../../features/settlement/settlement_screen.dart';
import '../../features/settlement/promptpay_screen.dart';
import '../../features/splash/splash_screen.dart';

/// Listens to authProvider and notifies GoRouter to re-run redirect
/// whenever the auth state changes (loading → data/error).
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(Ref ref) {
    ref.listen<AsyncValue<User?>>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    // Start on splash — shown while authProvider is doing its async init.
    // Once resolved, refreshListenable fires and redirect routes the user.
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final onSplash = state.matchedLocation == '/splash';

      // Still initialising → stay on splash
      if (auth.isLoading) return onSplash ? null : '/splash';

      final isLoggedIn = auth.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      final isOnAuthPage =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Finished loading: leave the splash screen
      if (onSplash) return isLoggedIn ? '/' : '/login';

      // Normal guards
      if (!isLoggedIn && !isOnAuthPage) return '/login';
      if (isLoggedIn && isOnAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/bill/create',
        builder: (context, state) => const CreateBillScreen(),
      ),
      GoRoute(
        path: '/bill/:id/items',
        builder: (context, state) =>
            AddItemsScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id/summary',
        builder: (context, state) =>
            BillSummaryScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id/edit',
        builder: (context, state) =>
            EditBillScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id/assign',
        builder: (context, state) =>
            AssignScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id/ocr',
        builder: (context, state) =>
            OcrReviewScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/bill/:id/invite',
        builder: (context, state) =>
            InviteScreen(billId: state.pathParameters['id']!),
      ),
      // GoRoute(path: '/bill/:id/assign', builder: (_, __) => const Placeholder()),
      // GoRoute(path: '/bill/:id/settlement', builder: (_, __) => const Placeholder()),
      GoRoute(path: '/join', builder: (context, state) => const JoinScreen()),
      GoRoute(
        path: '/bill/:id/settlement',
        builder: (context, state) =>
            SettlementScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id/promptpay/:toUserId/:amount',
        builder: (context, state) => PromptpayScreen(
          billId: state.pathParameters['id']!,
          toUserId: state.pathParameters['toUserId']!,
          toUserName: state.uri.queryParameters['name'] ?? 'Unknown',
          amount: double.tryParse(state.uri.queryParameters['amount'] ?? '0') ?? 0,
        ),
      ),
    ],
  );
});
