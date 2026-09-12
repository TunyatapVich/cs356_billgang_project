import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_app_bar.dart';
import 'bill_provider.dart';
import 'bill_service.dart';

class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen> {
  final _picker = ImagePicker();
  bool _scanning = false;
  int _ocrStep = 0;
  String? _error;

  static const _ocrSteps = [
    'Preparing receipt image',
    'Reading receipt text',
    'Organizing items and prices',
  ];

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      setState(() {
        _scanning = true;
        _ocrStep = 0;
        _error = null;
      });

      final billService = ref.read(billServiceProvider);
      // 1. Create a draft bill
      final createResult = await billService.createBill(
        name: 'Scanned receipt',
        date: DateTime.now(),
        vatPercent: 0,
        serviceChargePercent: 0,
      );
      final bill = createResult['bill'] as Map<String, dynamic>;
      final billId = bill['id'] as String;

      if (!mounted) return;
      setState(() => _ocrStep = 1);

      // 2. Run OCR with image file
      final imageFile = File(picked.path);
      final imageBytes = await imageFile.readAsBytes();
      final ocrItems = await billService.runOcr(
        billId: billId,
        rawText: '',
        imageBytes: imageBytes,
        imageMimeType: 'image/jpeg',
      );

      if (!mounted) return;
      setState(() => _ocrStep = 2);

      // 3. Add items to bill if detected
      if (ocrItems.isNotEmpty) {
        await billService.addItemsBulk(billId: billId, items: ocrItems);
      }

      ref.read(billListProvider.notifier).refreshBills();

      if (!mounted) return;
      context.go('/bill/$billId/items');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Failed to scan receipt: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _showScanPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Receipt Image',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dimBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primaryBlue),
              ),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Capture using device camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndScan(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dimBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.primaryBlue),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pick existing image or slip'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndScan(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.dimBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reading receipt...',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we process your image.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Column(
                  children: List.generate(_ocrSteps.length, (index) {
                    final isCurrent = index == _ocrStep;
                    final isDone = index < _ocrStep;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.dimBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone
                                ? Icons.check_circle
                                : isCurrent
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                            size: 18,
                            color: isCurrent || isDone ? AppColors.primaryBlue : AppColors.textGray,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _ocrSteps[index],
                            style: TextStyle(
                              color: isCurrent ? AppColors.primaryBlue : AppColors.textDark,
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: const ScreenAppBar(title: 'New Bill', backHref: '/'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: AppColors.dimBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                color: AppColors.primaryBlue,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'New Bill',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how you want to add items to your bill.',
              style: TextStyle(color: AppColors.textGray, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_error != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                        _error!,
                        style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Option 1: Scan Receipt (Blue Card)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showScanPicker,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan Receipt',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Take a photo of your receipt and let AI extract the items automatically.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 26),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Option 2: Create Manually (White Card)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/bill/create'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.inputBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.dimBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.add, color: AppColors.primaryBlue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Manually',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enter items and prices by hand at your own pace.',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.primaryBlue, size: 26),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Helper Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.6)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_outline, color: AppColors.primaryBlue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invite friends after creating the bill to assign items collaboratively.',
                      style: TextStyle(color: AppColors.textGray, fontSize: 13, height: 1.4),
                    ),
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
