import 'package:cs356_billgang/features/bill/bill_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key});

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  // ── สี ──────────────────────────────────────────────────────────────────
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputFill = Color(0xFFF2F4FC);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFD94848);
  String? _errorMessage;

  Future<void> _creatbill() async {
    setState(() => _errorMessage = null);
    await ref
        .read(billProvider.notifier)
        .createBill(name: 'Test Bill', date: DateTime.now(), vatPercent: 10);
    final billState = ref.read(billProvider);
    billState.when(
      data: (bill) {
        if (bill != null) {
          ref.invalidate(billListProvider);
          context.go('/bills');
        }
      },
      error: (e, _) => setState(() => _errorMessage = e.toString()),
      loading: () {},
    );
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
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
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

  // ── Stepper ──────────────────────────────────────────────────────────────
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

  // ── Bill Details Card ────────────────────────────────────────────────────
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
          // Header
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
          _buildInputField(label: 'Bill Name', hint: "Dinner at Joe's"),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Date',
            hint: 'Oct 24, 2023',
            prefixIcon: Icons.calendar_today_outlined,
            hintColor: textDark,
          ),
          const SizedBox(height: 16),

          // Service Charge + VAT (แถวเดียวกัน)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Service Charge (%)',
                  hint: '10',
                  hintColor: textDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: 'VAT (%)',
                  hint: 'abc',
                  hintColor: textDark,
                  isError: true,
                  errorText: 'Invalid input',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    IconData? prefixIcon,
    Color? hintColor,
    bool isError = false,
    String? errorText,
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
          height: 52,
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isError ? errorRed : inputBorder),
          ),
          child: TextField(
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
        if (isError && errorText != null) ...[
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

  // ── Bottom Info Cards ────────────────────────────────────────────────────
  Widget _buildBottomInfoCards() {
    return Row(
      children: [
        // Total Accuracy
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

        // Recent Splits
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

  // ── Create Button ────────────────────────────────────────────────────────
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
        onPressed: _creatbill,
        child: const Row(
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
}
