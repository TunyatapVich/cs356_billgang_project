import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  String? _qrData;
  String? _promptpayNumber;
  String? _fetchedToUserName;
  bool _loading = true;
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
            TextButton(
              onPressed: () => context.go('/bill/${widget.billId}/settlement'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/bill/${widget.billId}/settlement'),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    final generator = ThaiQRGenerator();
    final qrPayload = generator.generateCodeFromMobileOrId(
      _promptpayNumber!,
      (widget.rawAmount ?? widget.amount.toStringAsFixed(2)),
    );

    return Center(
      child: Container(
        width: 350,
        margin: const EdgeInsets.all(16),
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
            // 1. Blue banner with Thai QR logo - full width
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.thaiQRBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Image.asset(
                'assets/header.png',
                fit: BoxFit.cover,
              ),
            ),
            // 2. QR Code with PromptPay logo centered inside
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
                  QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  Image.asset(
                    'assets/logo.png',
                    height: 38,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
