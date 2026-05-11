import 'package:cs356_billgang/features/bill/bill_receipt_screen.dart';
import 'package:cs356_billgang/features/bill/bill_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/bill/Bill_Screen/billall_screen.dart';
import '../../features/bill/Bill_Screen/createbill_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // GoRoute(path: '/profile-setup', builder: (_, __) => const Placeholder()),
    GoRoute(path: '/bills', builder: (context, state) => const BillallScreen()),
    GoRoute(
      path: '/bill/create',
      builder: (context, state) => const CreateBillScreen(),
    ),
    
    GoRoute(
      path: '/bill/:id',
      builder: (context, state) =>
          BillReceiptScreen(billId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/bill/:id/summary',
      builder: (context, state) =>
          BillSummaryScreen(billId: state.pathParameters['id']!),
    ),
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
