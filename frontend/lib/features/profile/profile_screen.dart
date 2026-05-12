import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _promptpayController = TextEditingController();
  String? _errorMessage;
  bool _controllersInitialized = false;

  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFE84545);

  String? _promptpayError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersInitialized) {
      final authState = ref.watch(authProvider);
      authState.whenData((user) {
        if (user != null) {
          _displayNameController.text = user.displayName ?? '';
          _promptpayController.text = user.promptpayNumber ?? '';
          _controllersInitialized = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _promptpayController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _promptpayError = null;
    });

    final promptpay = _promptpayController.text.trim();
    if (promptpay.isNotEmpty && promptpay.length < 10) {
      setState(() => _promptpayError = 'PromptPay number must be at least 10 digits');
      valid = false;
    }

    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _errorMessage = null);
    await ref.read(authProvider.notifier).updateProfile(
      displayName: _displayNameController.text.trim(),
      promptpayNumber: _promptpayController.text.trim(),
    );
    final authState = ref.read(authProvider);
    authState.when(
      data: (user) {
        if (user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
          context.go('/');
        }
      },
      error: (e, _) => setState(() => _errorMessage = e.toString()),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: textDark),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAvatarPreview(),
                const SizedBox(height: 32),
                _buildDisplayNameField(),
                const SizedBox(height: 16),
                _buildPromptpayField(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(_errorMessage!),
                ],
                const SizedBox(height: 24),
                _buildSaveButton(isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final authState = ref.watch(authProvider);
    String? avatarUrl;
    authState.whenData((user) {
      avatarUrl = user?.avatarUrl;
    });

    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: primaryBlue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: hasAvatar
            ? ClipOval(
                child: Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  width: 96,
                  height: 96,
                  errorBuilder: (context, error, stackTrace) => _buildAvatarPlaceholder(),
                ),
              )
            : _buildAvatarPlaceholder(),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return const Center(
      child: Icon(Icons.person, color: primaryBlue, size: 48),
    );
  }

  Widget _buildDisplayNameField() {
    return _buildTextField(
      controller: _displayNameController,
      hintText: 'Display name',
      prefixIcon: Icons.person_outline,
    );
  }

  Widget _buildPromptpayField() {
    return _buildTextField(
      controller: _promptpayController,
      hintText: 'PromptPay number (optional)',
      prefixIcon: Icons.phone_android_outlined,
      keyboardType: TextInputType.phone,
      errorText: _promptpayError,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: textDark, fontSize: 15),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: textGray, fontSize: 14),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: textGray, size: 20)
                  : null,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: cardWhite,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: errorText != null ? errorRed : inputBorder,
                  width: errorText != null ? 1.2 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: errorText != null ? errorRed : primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(color: errorRed, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: errorRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isLoading) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
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
                'Save Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
