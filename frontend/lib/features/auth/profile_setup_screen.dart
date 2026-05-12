import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _displayNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _promptpayController = TextEditingController();
  String? _errorMessage;
  String? _displayNameError;
  String? _promptpayError;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    final authState = ref.read(authProvider);
    authState.whenData((user) {
      if (user != null) {
        _displayNameController.text = user.displayName ?? '';
        _avatarUrlController.text = user.avatarUrl ?? '';
        _promptpayController.text = user.promptpayNumber ?? '';
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    _promptpayController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _displayNameError = null;
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
      avatarUrl: _avatarUrlController.text.trim(),
      promptpayNumber: _promptpayController.text.trim(),
    );
    final authState = ref.read(authProvider);
    authState.when(
      data: (user) {
        if (user != null) context.go('/');
      },
      error: (e, _) => setState(() => _errorMessage = e.toString()),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
                AppTextField(
                  controller: _displayNameController,
                  hintText: 'Display name',
                  prefixIcon: Icons.person_outline,
                  errorText: _displayNameError,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _avatarUrlController,
                  hintText: 'Avatar URL (optional)',
                  prefixIcon: Icons.image_outlined,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _promptpayController,
                  hintText: 'PromptPay number (optional)',
                  prefixIcon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  errorText: _promptpayError,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _errorMessage!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Save Profile',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: _avatarUrlController.text.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _avatarUrlController.text,
                      fit: BoxFit.cover,
                      width: 96,
                      height: 96,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildAvatarPlaceholder(),
                    ),
                  )
                : _buildAvatarPlaceholder(),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return const Center(
      child: Icon(Icons.person, color: AppColors.primaryBlue, size: 48),
    );
  }
}
