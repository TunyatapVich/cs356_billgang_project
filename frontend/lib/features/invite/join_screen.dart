import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../core/widgets/screen_app_bar.dart';
import '../bill/bill_provider.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeController = TextEditingController();
  bool _isScanning = false;
  String? _error;
  bool _loading = false;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  String? _extractCode(String raw) {
    final match = RegExp(r'[A-Z]{3}\d{5}', caseSensitive: false).firstMatch(raw.trim());
    return match?.group(0)?.toUpperCase();
  }

  Future<void> _joinByCode(String code) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(authDioProvider).post('/bills/join/$code');
      final data = response.data as Map<String, dynamic>;
      final bill = data['bill'] as Map<String, dynamic>?;
      final billId = bill?['id'] as String?;

      if (!mounted) return;
      if (billId != null) {
        ref.read(billListProvider.notifier).refreshBills();
        context.go('/bill/$billId/assign');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _loading = false;
      });
    }
  }

  void _onCodeSubmit() {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) return;
    final code = _extractCode(raw);
    if (code == null) {
      setState(() => _error = 'Enter a valid invite code or deep link.');
      return;
    }
    _joinByCode(code);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_loading) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue ?? '';
    final code = _extractCode(raw);
    if (code == null) return;
    _scannerController?.dispose();
    setState(() => _isScanning = false);
    _joinByCode(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenAppBar(title: 'Join Bill', backHref: '/'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    _buildHero(),
                    const SizedBox(height: 20),
                    const Text(
                      'Join a Bill',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the invite code or scan the QR code from your friend.',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      _buildError(_error!),
                      const SizedBox(height: 16),
                    ],
                    if (_isScanning)
                      _buildScannerCard()
                    else ...[
                      _buildCodeInput(),
                      const SizedBox(height: 16),
                      _buildJoinButton(),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildScanButton(),
                      const SizedBox(height: 20),
                      _buildInfoCard(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E6FF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.qr_code_2, color: AppColors.primaryBlue, size: 72),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.group, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _codeController,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
          color: AppColors.primaryBlue,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'ABC12345',
          hintStyle: TextStyle(
            color: AppColors.textGray.withValues(alpha: 0.5),
            letterSpacing: 3,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(10),
        ],
        onSubmitted: (_) => _onCodeSubmit(),
      ),
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: _loading ? null : _onCodeSubmit,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Join Bill',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.inputBorder)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: TextStyle(color: AppColors.textGray, fontSize: 14)),
        ),
        Expanded(child: Container(height: 1, color: AppColors.inputBorder)),
      ],
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: () {
          setState(() {
            _error = null;
            _isScanning = true;
          });
        },
        icon: const Icon(Icons.qr_code_scanner, size: 20),
        label: const Text(
          'Scan QR Code',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildScannerCard() {
    _scannerController ??= MobileScannerController();
    return Column(
      children: [
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inputBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: MobileScanner(
            controller: _scannerController!,
            onDetect: _onBarcodeDetected,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Point your camera at the invite QR code.',
          style: TextStyle(color: AppColors.textGray, fontSize: 14),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: const BorderSide(color: AppColors.inputBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              _scannerController?.dispose();
              _scannerController = null;
              setState(() => _isScanning = false);
            },
            child: const Text('Cancel scan'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E6FF).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.qr_code_scanner, size: 18, color: AppColors.textGray),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Camera access is required to scan an invite QR code.',
              style: TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
