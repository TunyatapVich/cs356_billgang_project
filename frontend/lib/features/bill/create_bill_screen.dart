import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bill_provider.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputFill = Color(0xFFF2F4FC);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFD94848);

  final _nameController = TextEditingController();
  final _serviceController = TextEditingController(text: '0');
  final _vatController = TextEditingController(text: '7');

  DateTime _date = DateTime.now();
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
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
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
      setState(() => _error = 'Bill name is required');
      return;
    }

    final service = double.tryParse(_serviceController.text.trim());
    final vat = double.tryParse(_vatController.text.trim());
    if (service == null || service < 0 || vat == null || vat < 0) {
      setState(() => _error = 'Enter valid numbers for service and VAT');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    await ref.read(billProvider.notifier).createBill(
          name: name,
          date: _date,
          vatPercent: vat,
          serviceChargePercent: service,
        );

    if (!mounted) return;

    final billState = ref.read(billProvider);
    billState.when(
      data: (bill) {
        if (bill != null) {
          ref.invalidate(billListProvider);
          context.go('/bill/${bill.id}/summary');
        }
      },
      error: (e, _) => setState(() => _error = e.toString()),
      loading: () {},
    );

    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Create Bill',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            _buildHero(),
            const SizedBox(height: 24),
            const Text(
              'New Bill',
              style: TextStyle(
                color: textDark,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter bill details to get started.',
              style: TextStyle(color: textGray, fontSize: 16, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildInputCard(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildError(_error!),
            ],
            const SizedBox(height: 24),
            _buildCreateButton(),
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
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E6FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long, color: primaryBlue, size: 56),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Bill Name',
            hint: "Dinner at Joe's",
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: null,
            label: 'Date',
            hint: _formatDate(_date),
            readOnly: true,
            onTap: _pickDate,
            prefixIcon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _serviceController,
                  label: 'Service (%)',
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_decimalFormatter],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _vatController,
                  label: 'VAT (%)',
                  hint: '7',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_decimalFormatter],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController? controller,
    required String label,
    required String hint,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textGray,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: inputBorder),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: hint,
              hintStyle: TextStyle(
                color: textGray.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: textGray, size: 18)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.toString(),
              style: const TextStyle(color: errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
