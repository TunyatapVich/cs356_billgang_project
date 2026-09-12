import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_app_bar.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _screenshotController = ScreenshotController();
  String? _inviteCode;
  String? _deepLink;
  Object? _error;
  bool _loading = true;
  bool _savingQr = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(authDioProvider).post('/bills/${widget.billId}/invite');
      final data = response.data as Map<String, dynamic>;
      final code = (data['invite_code'] ?? data['inviteCode'] ?? '') as String;
      final link = (data['deep_link'] ?? data['deepLink'] ?? 'billgang://join/$code') as String;

      if (!mounted) return;
      setState(() {
        _inviteCode = code;
        _deepLink = link;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _copyText(String text, {required String message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _saveQrImage() async {
    if (_savingQr) return;
    setState(() => _savingQr = true);
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) {
        _showSnackBar('Failed to capture QR code');
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'billgang_invite_${_inviteCode ?? 'qr'}',
      );

      if (result['isSuccess'] == true) {
        _showSnackBar('QR code saved to gallery');
      } else {
        _showSnackBar('Failed to save QR code');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: ScreenAppBar(
        title: 'Invite',
        backHref: '/bill/${widget.billId}/summary',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          _buildHero(),
          const SizedBox(height: 20),
          const Text(
            'Invite Friends',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this QR code or link with your friends to join this bill.',
            style: TextStyle(color: AppColors.textGray, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Invite Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.inputBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
              ],
            ),
            child: Column(
              children: [
                // QR Code
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: QrImageView(
                      data: _deepLink ?? _inviteCode ?? 'billgang',
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Code Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.dimBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _inviteCode ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppColors.primaryBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                // Action row 1: Copy code & Save QR
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _copyText(_inviteCode ?? '', message: 'Invite code copied!'),
                        icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                        label: Text(_copied ? 'Copied' : 'Copy Code', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _saveQrImage,
                        icon: _savingQr
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download, size: 16),
                        label: const Text('Save QR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                if (_deepLink != null) ...[
                  const SizedBox(height: 14),
                  // Deep link box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invite Link', style: TextStyle(color: AppColors.textGray, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          _deepLink!,
                          style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _copyText(_deepLink!, message: 'Link copied!'),
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Copy Link', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Regenerate code button
                TextButton.icon(
                  onPressed: _loadCode,
                  icon: const Icon(Icons.refresh, size: 16, color: AppColors.primaryBlue),
                  label: const Text('Generate New Code', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Back button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => context.go('/bill/${widget.billId}/summary'),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Summary', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            color: AppColors.dimBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.link, color: AppColors.primaryBlue, size: 56),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.errorRed, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Unable to load invite code',
              style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _error.toString(),
              style: const TextStyle(color: AppColors.textGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadCode,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
