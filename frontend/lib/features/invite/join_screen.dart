import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api/api_client.dart';
import '../bill/bill_provider.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {

  final _codeController = TextEditingController();
  bool _isScanning = false;
  Object? _error;
  bool _loading = false;
  String? _billId;
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  String? _extractCode(String raw) {
    final trimmed = raw.trim().toUpperCase();
    if (RegExp(r'^[A-Z]{3}\d{5}$').hasMatch(trimmed)) return trimmed;
    final deepLinkMatch = RegExp(r'billgang://join/([A-Z]{3}\d{5})').firstMatch(raw);
    if (deepLinkMatch != null) return deepLinkMatch.group(1)!.toUpperCase();
    if (RegExp(r'^[A-Z]{3}\d{5}$').hasMatch(raw.toUpperCase())) return raw.toUpperCase();
    return null;
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
      _billId = bill?['id'] as String?;

      if (!mounted) return;
      if (_billId != null) {
        ref.read(billListProvider.notifier).refreshBills();
        context.go('/bill/$_billId/items');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onCodeSubmit() {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) return;
    final code = _extractCode(raw);
    if (code == null) {
      setState(() => _error = Exception('Invalid invite code format'));
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
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Join Bill',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isScanning ? _buildScanner() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _buildHero(),
          const SizedBox(height: 24),
          const Text(
            'Join a Bill',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the invite code or scan the QR code from your friend.',
            style: TextStyle(color: AppColors.textGray, fontSize: 16, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildCodeInput(),
          const SizedBox(height: 16),
          _buildJoinButton(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildError(_error!),
          ],
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
          _buildScanButton(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E6FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.qr_code_scanner, color: AppColors.primaryBlue, size: 72),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.group_add, color: Colors.white, size: 24),
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
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _codeController,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          color: AppColors.primaryBlue,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'ABC12345',
          hintStyle: TextStyle(
            color: AppColors.textGray.withValues(alpha: 0.5),
            letterSpacing: 2,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(8),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
        onPressed: () => setState(() => _isScanning = true),
        icon: const Icon(Icons.qr_code_scanner, size: 20),
        label: const Text(
          'Scan QR Code',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    _scannerController ??= MobileScannerController();
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onBarcodeDetected,
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at QR code',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              child: TextButton(
                onPressed: () {
                  _scannerController?.dispose();
                  _scannerController = null;
                  setState(() => _isScanning = false);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object error) {
    return Container(
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
              error.toString(),
              style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
