import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_provider.dart';
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

  // Slip preview
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
      final result = await ref
          .read(paymentServiceProvider)
          .create(
            billId: widget.billId,
            fromUserId: currentUser.id,
            toUserId: widget.toUserId,
            amount: widget.amount,
          );
      _qrData = result['qr_data'] as String?;
      _paymentId =
          (result['payment'] as Map<String, dynamic>?)?['id'] as String?;
      final toUser = result['to_user'] as Map<String, dynamic>?;
      _promptpayNumber = toUser?['promptpay_number'] as String?;
      _fetchedToUserName =
          toUser?['display_name'] as String? ?? _fetchedToUserName;
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
          _loading
              ? 'Loading...'
              : '฿${widget.rawAmount ?? widget.amount.toStringAsFixed(2)}',
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
            const Icon(
              Icons.error_outline,
              color: AppColors.errorRed,
              size: 42,
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

    final amountDouble =
        double.tryParse(widget.rawAmount ?? widget.amount.toStringAsFixed(2)) ??
        widget.amount.toDouble();

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
                // To: name chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dimBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: AppColors.primaryBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ชำระให้ ${_fetchedToUserName ?? widget.toUserName}',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // QR Card
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        // Header banner
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: Image.asset(
                            'assets/header.png',
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // QR
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: AppColors.inputBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: QrImageView(
                                  data: qrPayload,
                                  version: QrVersions.auto,
                                  size: 180,
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

                const SizedBox(height: 28),

                // Slip upload section
                if (!_slipUploaded)
                  _buildSlipUploadZone() //
                else
                  _buildSlipSuccessCard(),

                const SizedBox(height: 20),
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
              child: _slipUploaded
                  ? _buildFinishedSection()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _slipBytes != null
                            ? AppColors.successGreen
                            : AppColors.inputBorder,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _slipBytes != null && !_uploadingSlip
                          ? _confirmSlip
                          : null,
                      child: Text(
                        _slipBytes == null
                            ? 'กดเลือกสลิปด้านบนก่อน'
                            : _uploadingSlip
                            ? 'กำลังอัพโหลด...'
                            : 'ยืนยันสลิป',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _slipBytes != null
                ? AppColors.successGreen
                : AppColors.inputBorder,
            width: _slipBytes != null ? 2 : 1,
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.dimBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: _uploadingSlip
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(
                  Icons.upload_file,
                  color: AppColors.primaryBlue,
                  size: 28,
                ),
        ),
        const SizedBox(height: 14),
        const Text(
          'อัพสลิปยืนยันการโอน',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'แตะเพื่อเลือกรูปสลิปจากแกลเลอรี',
          style: TextStyle(fontSize: 13, color: AppColors.textGray),
        ),
      ],
    );
  }

  Widget _buildSlipPreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _slipBytes!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '✓ เลือกรูปแล้ว',
          style: TextStyle(
            color: AppColors.successGreen,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickSlip,
          child: const Text(
            'เปลี่ยนรูป',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
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
        color: AppColors.successGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          if (_slipBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _slipBytes!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สลิปพร้อมยืนยัน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'กดปุ่มด้านล่างเพื่อยืนยันการโอน',
                  style: TextStyle(fontSize: 13, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: AppColors.successGreen,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.successGreen, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'อัพสลิปเรียบร้อยแล้ว รอผู้รับตรวจสอบ',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => context.go('/bill/${widget.billId}/summary'),
            child: const Text(
              'เสร็จสิ้น',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoPromptpay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code, color: AppColors.textGray, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No PromptPay number set',
            style: TextStyle(color: AppColors.textGray, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => context.go('/bill/${widget.billId}/summary'),
            child: const Text('Go Back'),
          ),
        ],
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
      _showSnackBar('เลือกรูปไม่สำเร็จ');
    }
  }

  Future<void> _confirmSlip() async {
    if (_slipBytes == null || _uploadingSlip) return;

    if (_paymentId == null) {
      _showSnackBar('Payment not initialized — go back and try again.');
      return;
    }

    setState(() => _uploadingSlip = true);

    try {
      final result = await ref
          .read(paymentServiceProvider)
          .confirm(_paymentId!, slipBytes: _slipBytes);
      final billSettled = result['bill_settled'] as bool? ?? false;

      if (!mounted) return;
      setState(() {
        _uploadingSlip = false;
        _slipUploaded = true;
      });

      if (billSettled) {
        _showSnackBar('✅ บิลนี้ชำระครบแล้ว ทุกคนจ่ายครบแล้ว!');
      } else {
        _showSnackBar('ยืนยันสลิปเรียบร้อยแล้ว');
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go('/bill/${widget.billId}/summary');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingSlip = false);
      _showSnackBar(
        'Upload failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }
}
