import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_app_bar.dart';
import '../../core/widgets/avatar_stack.dart';
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
  String? _successMessage;
  bool _saving = false;
  Uint8List? _pickedAvatarBytes;
  final _picker = ImagePicker();
  String _selectedLanguage = 'en';

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

  Future<void> _pickAvatar() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedAvatarBytes = bytes;
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Display name is required');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).updateProfile(
            displayName: displayName,
            promptpayNumber: _promptpayController.text.trim(),
            avatarBytes: _pickedAvatarBytes,
          );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _successMessage = 'Profile updated.';
        _pickedAvatarBytes = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenAppBar(title: 'Profile', backHref: '/'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  children: [
                    // Main profile card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Avatar and email header
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _pickAvatar,
                                  child: Stack(
                                    children: [
                                      if (_pickedAvatarBytes != null)
                                        Container(
                                          width: 84,
                                          height: 84,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: MemoryImage(_pickedAvatarBytes!),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        )
                                      else
                                        UserAvatar(
                                          name: user?.displayName ?? 'User',
                                          avatarUrl: user?.avatarUrl,
                                          size: AvatarSize.large,
                                        ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryBlue,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Your profile',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Status messages
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
                          if (_successMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _successMessage!,
                                      style: const TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Display Name Input
                          const Text(
                            'DISPLAY NAME',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGray,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _displayNameController,
                            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: 'Enter display name',
                              hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 15),
                              filled: true,
                              fillColor: AppColors.bgLight,
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

                          // PromptPay Input
                          const Text(
                            'PROMPTPAY NUMBER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGray,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _promptpayController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: '08XXXXXXXX',
                              hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 15),
                              filled: true,
                              fillColor: AppColors.bgLight,
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
                          const SizedBox(height: 20),

                          // Save Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _saving ? null : _submit,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: const Text(
                                'Save profile',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Language Preference Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.language, size: 20, color: AppColors.textGray),
                              SizedBox(width: 10),
                              Text(
                                'Language',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildLangChip('English', 'en'),
                              const SizedBox(width: 8),
                              _buildLangChip('ภาษาไทย', 'th'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.errorRed,
                          side: BorderSide(color: AppColors.errorRed.withValues(alpha: 0.5)),
                          backgroundColor: AppColors.errorRed.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Sign out'),
                              content: const Text('Are you sure you want to sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.errorRed,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) context.go('/login');
                          }
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text(
                          'Sign out',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangChip(String label, String code) {
    final isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = code);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.inputBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
