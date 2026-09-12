import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_app_bar.dart';
import 'bill_provider.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  final _nameController = TextEditingController();
  final _serviceController = TextEditingController(text: '10');
  final _vatController = TextEditingController(text: '7');

  DateTime _date = DateTime.now();
  bool _serviceEnabled = false;
  bool _vatEnabled = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _serviceController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}'),
  );

  Future<void> _submit() async {
    if (_submitting) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a bill name');
      return;
    }

    double service = 0;
    if (_serviceEnabled) {
      final parsedService = double.tryParse(_serviceController.text.trim());
      if (parsedService == null || parsedService < 0) {
        setState(() => _error = 'Please enter a valid service charge');
        return;
      }
      service = parsedService;
    }

    double vat = 0;
    if (_vatEnabled) {
      final parsedVat = double.tryParse(_vatController.text.trim());
      if (parsedVat == null || parsedVat < 0) {
        setState(() => _error = 'Please enter a valid VAT percentage');
        return;
      }
      vat = parsedVat;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(billProvider.notifier)
          .createBill(
            name: name,
            date: _date,
            vatPercent: vat,
            serviceChargePercent: service,
          );

      if (!mounted) return;

      final billState = ref.read(billProvider);
      billState.whenOrNull(
        data: (bill) {
          if (bill != null) {
            ref.invalidate(billListProvider);
            context.go('/bill/${bill.id}/items');
          }
        },
        error: (e, _) => setState(() => _error = e.toString().replaceFirst('Exception: ', '')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: const ScreenAppBar(title: 'Create Manually', backHref: '/bill/new'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back to options
            InkWell(
              onTap: () => context.go('/bill/new'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, color: AppColors.primaryBlue, size: 20),
                    Text(
                      'Back to options',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card: Bill Details
            Container(
              padding: const EdgeInsets.all(22),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.dimBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.receipt, color: AppColors.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill Details',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enter basic bill information below',
                              style: TextStyle(color: AppColors.textGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
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
                  // Bill Name
                  const Text(
                    'Bill Name',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        hintText: "e.g. Dinner at Joe's",
                        hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Date
                  const Text(
                    'Date',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: AppColors.textGray, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _formatDate(_date),
                            style: const TextStyle(color: AppColors.textDark, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Service Charge & VAT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service charge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _serviceEnabled = !_serviceEnabled),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _serviceEnabled,
                                      activeColor: AppColors.primaryBlue,
                                      onChanged: (val) => setState(() => _serviceEnabled = val ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Service Charge',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_serviceEnabled) ...[
                              const SizedBox(height: 8),
                              Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.inputBorder),
                                ),
                                child: TextField(
                                  controller: _serviceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [_decimalFormatter],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    suffixText: '%',
                                    suffixStyle: TextStyle(color: AppColors.textGray),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // VAT
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _vatEnabled = !_vatEnabled),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _vatEnabled,
                                      activeColor: AppColors.primaryBlue,
                                      onChanged: (val) => setState(() => _vatEnabled = val ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'VAT (7%)',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_vatEnabled) ...[
                              const SizedBox(height: 8),
                              Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.inputBorder),
                                ),
                                child: TextField(
                                  controller: _vatController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [_decimalFormatter],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    suffixText: '%',
                                    suffixStyle: TextStyle(color: AppColors.textGray),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Create Bill',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
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

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
