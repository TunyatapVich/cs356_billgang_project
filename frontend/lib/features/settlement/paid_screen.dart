import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_app_bar.dart';
import '../auth/auth_provider.dart';
import '../bill/bill_provider.dart';
import 'payment_service.dart';
import 'promptpay_utils.dart';

class PaidScreen extends ConsumerStatefulWidget {
  const PaidScreen({
    super.key,
    required this.billId,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    this.qrData,
    this.rawAmount,
  });

  final String billId;
  final String toUserId;
  final String toUserName;
  final double amount;
  final String? qrData;
  final String? rawAmount;

  @override
  ConsumerState<PaidScreen> createState() => _PaidScreenState();
}

class _PaidScreenState extends ConsumerState<PaidScreen> {
  final _screenshotController = ScreenshotController();
  final _imagePicker = ImagePicker();
  String? _qrData;
  String? _promptpayNumber;
  String? _fetchedToUserName;
  String? _paymentId;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingSlip = false;
  bool _slipUploaded = false;
  Object? _error;

  Uint8List? _slipBytes;

  @override
  void initState() {
    super.initState();
    _qrData = widget.qrData;
    _fetchedToUserName = widget.toUserName;
    if (_qrData == null) {
      _loadQrData();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadQrData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = ref.read(authProvider).value;
      if (currentUser == null) throw Exception('Not authenticated');
      final result = await ref.read(paymentServiceProvider).create(
            billId: widget.billId,
            fromUserId: currentUser.id,
            toUserId: widget.toUserId,
            amount: widget.amount,
          );
      _qrData = result['qr_data'] as String?;
      final payment = result['payment'] as Map<String, dynamic>?;
      _paymentId = result['payment_id'] as String? ?? payment?['id']?.toString();
      final toUser = result['to_user'] as Map<String, dynamic>?;
      _promptpayNumber = toUser?['promptpay_number'] as String?;
      _fetchedToUserName = toUser?['display_name'] as String? ?? _fetchedToUserName;
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _saveQrImage() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) {
        _showSnackBar('Failed to capture QR code');
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'billgang_qr_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess'] == true) {
        _showSnackBar('QR code saved to gallery');
      } else {
        _showSnackBar('Failed to save QR code');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickSlip() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _slipBytes = bytes);
    } catch (e) {
      _showSnackBar('Failed to select image');
    }
  }

  Future<void> _confirmSlip() async {
    if (_slipBytes == null || _uploadingSlip) return;

    if (_paymentId == null) {
      _showSnackBar('Payment not initialized — please try again.');
      return;
    }

    setState(() => _uploadingSlip = true);

    try {
      await ref.read(paymentServiceProvider).confirm(
            _paymentId!,
            slipBytes: _slipBytes,
          );

      if (!mounted) return;
      ref.invalidate(billListProvider);
      setState(() {
        _uploadingSlip = false;
        _slipUploaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingSlip = false);
      _showSnackBar('Failed to upload slip: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleAmount = widget.rawAmount ?? widget.amount.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: ScreenAppBar(
        title: '฿$titleAmount',
        backHref: '/bill/${widget.billId}/summary',
        action: (!_loading && _promptpayNumber != null)
            ? IconButton(
                icon: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, color: AppColors.primaryBlue),
                onPressed: _saving ? null : _saveQrImage,
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _error != null
              ? _buildError()
              : _buildContent(),
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
              onPressed: _loadQrData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_promptpayNumber == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, color: AppColors.textGray, size: 48),
            const SizedBox(height: 16),
            const Text('No PromptPay number set', style: TextStyle(color: AppColors.textGray, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/bill/${widget.billId}/summary'),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    final amountDouble = double.tryParse(widget.rawAmount ?? widget.amount.toStringAsFixed(2)) ?? widget.amount;
    final qrPayload = PromptPayUtils.generatePayload(
      promptpayId: _promptpayNumber!,
      amount: amountDouble,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Transfer to chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dimBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Transfer to ${_fetchedToUserName ?? widget.toUserName}',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Thai QR PromptPay Card
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                          child: Image.asset(
                            'assets/header.png',
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.inputBorder),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: QrImageView(
                                  data: qrPayload,
                                  version: QrVersions.auto,
                                  size: 190,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                child: Image.asset(
                                  'assets/logo.png',
                                  height: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Helper note
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dimBlue.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Save QR code and pay via your mobile banking app.',
                    style: TextStyle(color: AppColors.textDark, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // Slip upload zone
                if (!_slipUploaded)
                  _buildSlipUploadZone()
                else
                  _buildSlipSuccessCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Bottom CTA
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: _slipUploaded
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => context.go('/bill/${widget.billId}/summary'),
                      child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _slipBytes != null ? AppColors.primaryBlue : AppColors.inputBorder,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _slipBytes != null && !_uploadingSlip ? _confirmSlip : null,
                      child: _uploadingSlip
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _slipBytes == null ? 'Select slip above to confirm' : 'Confirm Paid',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlipUploadZone() {
    return GestureDetector(
      onTap: _uploadingSlip ? null : _pickSlip,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _slipBytes != null ? AppColors.successGreen : AppColors.inputBorder,
            width: _slipBytes != null ? 1.5 : 1,
          ),
        ),
        child: _slipBytes != null ? _buildSlipPreview() : _buildUploadPrompt(),
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.dimBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.upload_file, color: AppColors.primaryBlue, size: 26),
        ),
        const SizedBox(height: 12),
        const Text(
          'Upload transfer slip',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap to choose slip from gallery',
          style: TextStyle(fontSize: 12, color: AppColors.textGray),
        ),
      ],
    );
  }

  Widget _buildSlipPreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _slipBytes!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Slip selected',
          style: TextStyle(color: AppColors.successGreen, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickSlip,
          child: const Text(
            'Change slip',
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  Widget _buildSlipSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.successGreen, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Slip uploaded successfully',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                SizedBox(height: 2),
                Text(
                  'Waiting for receiver review.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
