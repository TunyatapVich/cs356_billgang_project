import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
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
  bool _isEditing = false;
  String? _displayNameError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initControllers);
  }

  void _initControllers() {
    final authState = ref.read(authProvider);
    authState.whenData((user) {
      if (user != null) {
        _displayNameController.text = user.displayName ?? '';
        _promptpayController.text = user.promptpayNumber ?? '';
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _promptpayController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() => _displayNameError = null);
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _displayNameError = 'Display name is required');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    if (!mounted) return;

    setState(() => _errorMessage = null);
    await ref.read(authProvider.notifier).updateProfile(
      displayName: _displayNameController.text.trim(),
      promptpayNumber: _promptpayController.text.trim(),
    );
    if (!mounted) return;

    final authState = ref.read(authProvider);
    authState.when(
      data: (user) {
        if (user != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
          setState(() => _isEditing = false);
        }
      },
      error: (e, _) {
        if (mounted) setState(() => _errorMessage = e.toString());
      },
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
        title: Text(
          _isEditing ? 'Edit Profile' : 'Profile',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: _isEditing
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primaryBlue),
                  onPressed: () => setState(() => _isEditing = true),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.textDark),
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
                AppTextField(
                  controller: _displayNameController,
                  hintText: 'Display name',
                  prefixIcon: Icons.person_outline,
                  readOnly: !_isEditing,
                  errorText: _displayNameError,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _promptpayController,
                  hintText: 'PromptPay number (optional)',
                  prefixIcon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  readOnly: !_isEditing,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _errorMessage!),
                ],
                const SizedBox(height: 24),
                if (_isEditing) ...[
                  PrimaryButton(
                    label: 'Save Profile',
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isEditing = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textGray,
                        side: const BorderSide(color: AppColors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: hasAvatar
            ? ClipOval(
                child: Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  width: 96,
                  height: 96,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildAvatarPlaceholder(),
                ),
              )
            : _buildAvatarPlaceholder(),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return const Center(
      child: Icon(Icons.person, color: AppColors.primaryBlue, size: 48),
    );
  }
}
