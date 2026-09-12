import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      valid = false;
    }

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
    } else if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      valid = false;
    }

    final confirm = _confirmController.text;
    if (confirm.isEmpty) {
      setState(() => _confirmError = 'Please confirm your password');
      valid = false;
    } else if (confirm != password) {
      setState(() => _confirmError = 'Passwords do not match');
      valid = false;
    }

    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _errorMessage = null);
    await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          passwordConfirm: _confirmController.text,
          displayName: _nameController.text.trim(),
          promptpayNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );

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
                      const SizedBox(height: 20),
                      const Text(
                        'Start splitting fairly',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create your free BillGang account.',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

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

                // Display Name field
                const Text(
                  'YOUR NAME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'What should friends call you?',
                    hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 15),
                    filled: true,
                    fillColor: AppColors.cardWhite,
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.textGray, size: 20),
                    errorText: _nameError,
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
                const SizedBox(height: 14),

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
                const SizedBox(height: 14),

                // PromptPay field
                Row(
                  children: const [
                    Text(
                      'PROMPTPAY NUMBER ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGray,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '(OPTIONAL)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: '08XXXXXXXX',
                    hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 15),
                    filled: true,
                    fillColor: AppColors.cardWhite,
                    prefixIcon: const Icon(Icons.phone_android_outlined, color: AppColors.textGray, size: 20),
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
                const SizedBox(height: 14),

                // Password and Confirm side-by-side or stacked
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              hintText: 'Min 8 chars',
                              hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.cardWhite,
                              errorText: _passwordError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textGray,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CONFIRM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGray,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: 'Repeat pass',
                              hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.cardWhite,
                              errorText: _confirmError,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textGray,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Create account button
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
                            'Create account',
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

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.textGray, fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Sign in',
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
