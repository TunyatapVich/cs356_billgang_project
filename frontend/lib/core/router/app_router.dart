import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/bill/bill_list_screen.dart';
import '../../features/bill/create_bill_screen.dart';
import '../../features/bill/add_items_screen.dart';
import '../../features/bill/ocr_review_screen.dart';
import '../../features/invite/invite_screen.dart';
import '../../features/invite/join_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/bills',
      builder: (context, state) => const BillListScreen(),
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
