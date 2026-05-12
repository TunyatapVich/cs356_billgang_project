import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:thaiqr/thaiqr.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_provider.dart';
import 'payment_service.dart';

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
    setState(() { _loading = true; _error = null; });
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
      _paymentId = result['payment_id'] as String?;
      final toUser = result['to_user'] as Map<String, dynamic>?;
      _promptpayNumber = toUser?['promptpay_number'] as String?;
      _fetchedToUserName = toUser?['display_name'] as String? ?? _fetchedToUserName;
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _saveQrImage() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => context.go('/bill/${widget.billId}/summary'),
        ),
        title: Text(
          _loading ? 'Loading...' : '฿${(widget.rawAmount ?? widget.amount.toStringAsFixed(2))}',
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_loading && _promptpayNumber != null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt, color: AppColors.primaryBlue),
              onPressed: _saving ? null : _saveQrImage,
            ),
          if (!_loading && _promptpayNumber != null)
            TextButton(
              onPressed: () => context.go('/bill/${widget.billId}/summary'),
              child: const Text(
                'Done',
                style: TextStyle(color: AppColors.primaryBlue, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
      return _buildNoPromptpay();
    }

    final generator = ThaiQRGenerator();
    final qrPayload = generator.generateCodeFromMobileOrId(
      _promptpayNumber!,
      (widget.rawAmount ?? widget.amount.toStringAsFixed(2)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // QR code card (screenshot-able)
          Screenshot(
            controller: _screenshotController,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Blue banner
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.thaiQRBlue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Image.asset('assets/header.png', fit: BoxFit.cover),
                  ),
                  // QR Code
                  Container(
                    width: 200,
                    height: 200,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(data: qrPayload, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
                        Image.asset('assets/logo.png', height: 38),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Slip upload section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppColors.primaryBlue, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'อัพสลิปยืนยันการโอน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_slipUploaded)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'อัพสลิปเรียบร้อยแล้ว รอตรวจสอบจากผู้รับ',
                            style: TextStyle(color: AppColors.successGreen, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _uploadingSlip ? null : _pickAndUploadSlip,
                    icon: _uploadingSlip
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_uploadingSlip ? 'กำลังอัพโหลด...' : 'เลือกรูปสลิป'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/bill/${widget.billId}/summary'),
              child: const Text('เสร็จสิ้น', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPromptpay() {
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

  Future<void> _pickAndUploadSlip() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      setState(() => _uploadingSlip = true);

      final bytes = await picked.readAsBytes();
      final slipUrl = await uploadSlipToCloudinary(bytes);

      if (_paymentId != null) {
        await ref.read(paymentServiceProvider).confirm(_paymentId!, slipUrl: slipUrl);
      }

      if (!mounted) return;
      setState(() { _uploadingSlip = false; _slipUploaded = true; });
      _showSnackBar('อัพสลิปเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingSlip = false);
      _showSnackBar('อัพสลิปไม่สำเร็จ: ${e.toString()}');
    }
  }
}
