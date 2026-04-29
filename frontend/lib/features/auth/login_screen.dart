// TODO 1: change StatelessWidget → ConsumerStatefulWidget
// ConsumerStatefulWidget = StatefulWidget that can also read Riverpod providers
// (you need StatefulWidget here because TextEditingControllers are stateful)
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';

// TODO 2: declare the widget
// class LoginScreen extends ConsumerStatefulWidget {
//   const LoginScreen({super.key});
//   @override
//   ConsumerState<LoginScreen> createState() => _LoginScreenState();
// }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

// TODO 3: write the State class
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  //   // TODO 3c: write _submit() — called when user taps Login button
  //   // Future<void> _submit() async {
  //   //   setState(() => _errorMessage = null);
  //   //   await ref.read(authProvider.notifier).login(
  //   //     _emailController.text.trim(),
  //   //     _passwordController.text,
  //   //   );
  //   //   final authState = ref.read(authProvider);
  //   //   authState.when(
  //   //     data: (user) {
  //   //       if (user != null) context.go('/home');   // navigate on success
  //   //     },
  //   //     error: (e, _) => setState(() => _errorMessage = e.toString()),
  //   //     loading: () {},
  //   //   );

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    await ref
        .read(authProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    final authState = ref.read(authProvider);
    authState.when(
      data: (user) {
        if (user != null) context.go('home');
      },
      error: (e, _) => setState(() => _errorMessage = e.toString()),
      loading: () {},
    );
  }
}

//   // TODO 4: build the UI
//   // @override
//   // Widget build(BuildContext context) {
//   //   final isLoading = ref.watch(authProvider).isLoading;  // same as checking loading state in Zustand
//   //
//   //   return Scaffold(
//   //     body: Padding(
//   //       padding: const EdgeInsets.all(24),
//   //       child: Column(
//   //         mainAxisAlignment: MainAxisAlignment.center,
//   //         children: [
//   //
//   //           // TODO 4a: app title or logo
//   //           const Text('BillGang', style: TextStyle(fontSize: 32)),
//   //           const SizedBox(height: 32),
//   //
//   //           // TODO 4b: email field
//   //           TextField(
//   //             controller: _emailController,
//   //             decoration: const InputDecoration(labelText: 'Email'),
//   //             keyboardType: TextInputType.emailAddress,
//   //           ),
//   //           const SizedBox(height: 16),
//   //
//   //           // TODO 4c: password field
//   //           TextField(
//   //             controller: _passwordController,
//   //             decoration: const InputDecoration(labelText: 'Password'),
//   //             obscureText: true,   // hides the password characters
//   //           ),
//   //           const SizedBox(height: 8),
//   //
//   //           // TODO 4d: error message (show only when _errorMessage is not null)
//   //           if (_errorMessage != null)
//   //             Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
//   //           const SizedBox(height: 16),
//   //
//   //           // TODO 4e: login button — show CircularProgressIndicator while loading
//   //           isLoading
//   //             ? const CircularProgressIndicator()
//   //             : ElevatedButton(
//   //                 onPressed: _submit,
//   //                 child: const Text('Login'),
//   //               ),
//   //           const SizedBox(height: 8),
//   //
//   //           // TODO 4f: link to register screen
//   //           TextButton(
//   //             onPressed: () => context.go('/register'),
//   //             child: const Text("Don't have an account? Register"),
//   //           ),
//   //
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
// }
