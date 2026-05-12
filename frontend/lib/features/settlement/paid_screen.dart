import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
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
      final result = await ref.read(paymentServiceProvider).create(
        billId: widget.billId,
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
        title: const Text(
          'Pay',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
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

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildQrCard(),
          if (_promptpayNumber != null) ...[
            const SizedBox(height: 20),
            _buildPhoneCard(),
          ],
          const SizedBox(height: 32),
          _buildDoneButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Pay',
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '฿${(widget.rawAmount ?? widget.amount.toStringAsFixed(2))}',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'to ${_fetchedToUserName ?? widget.toUserName}',
            style: const TextStyle(color: AppColors.primaryBlue, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    if (_qrData == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: const Center(
          child: Text(
            'No PromptPay number set',
            style: TextStyle(color: AppColors.textGray),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan with your banking app',
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone_android, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 10),
          Text(
            _promptpayNumber!,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => context.go('/bill/${widget.billId}/settlement'),
        child: const Text(
          "I've Paid",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
