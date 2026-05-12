import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bill_provider.dart';
import 'bill_service.dart';

class BillSummaryScreen extends ConsumerStatefulWidget {
  const BillSummaryScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends ConsumerState<BillSummaryScreen> {
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFD94848);

  Bill? _bill;
  List<BillItem> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ref.read(billServiceProvider).getBill(widget.billId);
      final bill = Bill.fromJson(data);
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final items = rawItems.cast<Map<String, dynamic>>().map(BillItem.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _bill = bill;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get _service => _subtotal * ((_bill?.serviceChargePercent ?? 0) / 100);
  double get _vat => _subtotal * ((_bill?.vatPercent ?? 0) / 100);
  double get _total => _subtotal + _service + _vat;

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
          'Bill Summary',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: errorRed, size: 42),
          const SizedBox(height: 12),
          Text(_error.toString(), style: const TextStyle(color: textGray)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
            onPressed: _loadBill,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final bill = _bill!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _buildHero(bill),
          const SizedBox(height: 20),
          _buildMemberRow(bill),
          const SizedBox(height: 20),
          _buildTotalCard(bill),
          const SizedBox(height: 16),
          _buildActionRow(),
          const SizedBox(height: 20),
          _buildItemList(),
        ],
      ),
    );
  }

  Widget _buildHero(Bill bill) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E6FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long, color: primaryBlue, size: 44),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bill.isActive
                  ? const Color(0xFF34C759)
                  : textGray.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (bill.isActive ? const Color(0xFF34C759) : textGray).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberRow(Bill bill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE4E6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.group, color: primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bill.memberCount} member${bill.memberCount == 1 ? '' : 's'}  ·  ${_formatDate(bill.date)}',
                  style: const TextStyle(color: textGray, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bill.isActive
                  ? const Color(0xFF34C759).withValues(alpha: 0.1)
                  : textGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bill.isActive ? 'Active' : 'Settled',
              style: TextStyle(
                color: bill.isActive ? const Color(0xFF34C759) : textGray,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(Bill bill) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(color: textGray, fontSize: 14)),
              Text('฿${_subtotal.toStringAsFixed(2)}', style: const TextStyle(color: textDark, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Service ${bill.serviceChargePercent ?? 0}%', style: const TextStyle(color: textGray, fontSize: 14)),
              Text('฿${_service.toStringAsFixed(2)}', style: const TextStyle(color: textDark, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('VAT ${bill.vatPercent ?? 0}%', style: const TextStyle(color: textGray, fontSize: 14)),
              Text('฿${_vat.toStringAsFixed(2)}', style: const TextStyle(color: textDark, fontSize: 14)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('฿${_total.toStringAsFixed(2)}', style: const TextStyle(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.add_circle_outline,
            label: 'Add Items',
            onTap: () => context.go('/bill/${widget.billId}/items'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            icon: Icons.group_add,
            label: 'Invite',
            onTap: () => context.go('/bill/${widget.billId}/invite'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            icon: Icons.restaurant,
            label: 'Assign',
            onTap: () => context.go('/bill/${widget.billId}/assign'),
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? primaryBlue : cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: isPrimary ? null : Border.all(color: inputBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.white : primaryBlue, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: inputBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, color: textGray.withValues(alpha: 0.4), size: 40),
            const SizedBox(height: 8),
            const Text('No items yet', style: TextStyle(color: textGray, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Items', style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(item.name, style: const TextStyle(color: textDark, fontSize: 14)),
              ),
              Text('x${item.quantity}', style: const TextStyle(color: textGray, fontSize: 13)),
              const SizedBox(width: 12),
              Text('฿${item.lineTotal.toStringAsFixed(2)}', style: const TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
