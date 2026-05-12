import 'package:cs356_billgang/features/bill/bill_receipt_screen.dart';
import 'package:cs356_billgang/features/bill/bill_summary_screen.dart';
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

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final container = ProviderScope.containerOf(context);
    final auth = container.read(authProvider);

    // If auth is still loading, don't redirect — let the splash/loading show
    if (auth.isLoading) return null;

    final isLoggedIn = auth.maybeWhen(
      data: (user) => user != null,
      orElse: () => false,
    );
    final isOnAuthPage = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    // If not logged in and not on auth page → go to login
    if (!isLoggedIn && !isOnAuthPage) return '/login';
    // If logged in and on auth page → go to home
    if (isLoggedIn && isOnAuthPage) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/bills',
      builder: (context, state) => const HomeScreen(),
    ),
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
      builder: (context, state) => const InviteScreen(),
    ),
    // GoRoute(path: '/bill/:id/assign', builder: (_, __) => const Placeholder()),
    // GoRoute(path: '/bill/:id/settlement', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/join', builder: (context, state) => const JoinScreen()),
  ],
);
