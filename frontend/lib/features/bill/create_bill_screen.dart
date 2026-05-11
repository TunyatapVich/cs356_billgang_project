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
  String? _formError;
  String? _nameError;
  String? _serviceError;
  String? _vatError;
  bool _submitting = false;

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

  bool _validate() {
    String? nameErr;
    String? svcErr;
    String? vatErr;

    if (_nameController.text.trim().isEmpty) {
      nameErr = 'Bill name is required';
    }
    final svc = double.tryParse(_serviceController.text.trim());
    if (svc == null || svc < 0) {
      svcErr = 'Enter a number ≥ 0';
    }
    final vat = double.tryParse(_vatController.text.trim());
    if (vat == null || vat < 0) {
      vatErr = 'Enter a number ≥ 0';
    }

    setState(() {
      _nameError = nameErr;
      _serviceError = svcErr;
      _vatError = vatErr;
    });

    return nameErr == null && svcErr == null && vatErr == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_validate()) return;

    setState(() {
      _submitting = true;
      _formError = null;
    });

    await ref.read(billProvider.notifier).createBill(
          name: _nameController.text.trim(),
          date: _date,
          vatPercent: double.parse(_vatController.text.trim()),
          serviceChargePercent: double.parse(_serviceController.text.trim()),
        );

    if (!mounted) return;

    final billState = ref.read(billProvider);
    billState.when(
      data: (bill) {
        if (bill != null) {
          ref.invalidate(billListProvider);
          context.go('/bill/${bill.id}/items');
        }
      },
      error: (e, _) => setState(() => _formError = e.toString()),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Bill',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: textDark),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildStepper(),
            const SizedBox(height: 30),
            _buildBillDetailsCard(),
            const SizedBox(height: 20),
            _buildBottomInfoCards(),
            const SizedBox(height: 30),
            if (_formError != null) ...[
              Text(
                _formError!,
                style: const TextStyle(color: errorRed, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            _buildCreateButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned(
          top: 20,
          left: 40,
          right: 40,
          child: SizedBox(height: 2, child: ColoredBox(color: inputFill)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepItem(icon: Icons.edit, label: 'Create', isActive: true),
            _buildStepItem(
              icon: Icons.group_add_outlined,
              label: 'Split',
              isActive: false,
            ),
            _buildStepItem(
              icon: Icons.check_circle_outline,
              label: 'Finish',
              isActive: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: isActive ? primaryBlue : inputFill,
          child: Icon(
            icon,
            color: isActive ? Colors.white : textGray,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? primaryBlue : textGray,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBillDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: primaryBlue),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Details',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Enter the information for the new bill.',
                      style: TextStyle(
                        color: textGray,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInputField(
            label: 'Bill Name',
            hint: "Dinner at Joe's",
            controller: _nameController,
            errorText: _nameError,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Date',
            hint: _formatDate(_date),
            prefixIcon: Icons.calendar_today_outlined,
            hintColor: textDark,
            readOnly: true,
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Service Charge (%)',
                  hint: '10',
                  controller: _serviceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalFormatter],
                  errorText: _serviceError,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: 'VAT (%)',
                  hint: '7',
                  controller: _vatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalFormatter],
                  errorText: _vatError,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}'),
  );

  Widget _buildInputField({
    required String label,
    required String hint,
    TextEditingController? controller,
    IconData? prefixIcon,
    Color? hintColor,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    final isError = errorText != null;
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
          height: 52,
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isError ? errorRed : inputBorder),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: hintColor ?? textGray.withValues(alpha: 0.5),
                fontSize: 15,
                fontWeight: hintColor != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: textGray, size: 20)
                  : null,
            ),
          ),
        ),
        if (isError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, color: errorRed, size: 14),
              const SizedBox(width: 4),
              Text(
                errorText,
                style: const TextStyle(color: errorRed, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBottomInfoCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Accuracy',
                  style: TextStyle(color: Color(0x884E54C8), fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  '99.9%',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(Colors.blue[100]!),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: _buildAvatar(Colors.pink[100]!),
                    ),
                    Transform.translate(
                      offset: const Offset(-16, 0),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFFE4E6FF),
                        child: Text(
                          '+6',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Recent Splits',
                  style: TextStyle(color: textGray, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Bill',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
