import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      valid = false;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    }

    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _errorMessage = null);
    await ref
        .read(authProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    final authState = ref.read(authProvider);
    authState.when(
      data: (user) {
        if (user != null && mounted) context.go('/');
      },
      error: (e, _) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          });
        }
      },
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryBlue, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 8,
                                  top: 11,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 11,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'BillGang',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Split the bill. Keep the friendship.',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Email field
                const Text(
                  'EMAIL ADDRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 15),
                    filled: true,
                    fillColor: AppColors.cardWhite,
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textGray, size: 20),
                    errorText: _emailError,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                const Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 15),
                    filled: true,
                    fillColor: AppColors.cardWhite,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textGray, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textGray,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    errorText: _passwordError,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign in Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Sign in',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: AppColors.inputBorder)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: TextStyle(color: AppColors.textGray, fontSize: 14)),
                    ),
                    Expanded(child: Container(height: 1, color: AppColors.inputBorder)),
                  ],
                ),
                const SizedBox(height: 24),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'New to BillGang? ',
                      style: TextStyle(color: AppColors.textGray, fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: const Text(
                        'Create an account',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
