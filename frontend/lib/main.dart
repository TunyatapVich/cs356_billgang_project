import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

// TODO 2: change main() to this
// void main() {
//   runApp(
//     const ProviderScope(   // <- same as <Provider> in React, must wrap everything
//       child: MyApp(),
//     ),
//   );
// }

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

// TODO 3: change MyApp to use MaterialApp.router (go_router needs this instead of MaterialApp)
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp.router(
//       title: 'BillGang',
//       routerConfig: appRouter,   // <- your route table from core/router/app_router.dart
//     );
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'BillGang', routerConfig: appRouter);
  }
}
