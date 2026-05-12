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
          const SizedBox(height: 16),
          _buildMemberRow(bill),
          const SizedBox(height: 16),
          _buildBillCard(bill),
          const SizedBox(height: 16),
          _buildPersonSplit(),
          const SizedBox(height: 20),
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildHero(Bill bill) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFE4E6FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long, color: primaryBlue, size: 36),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(7),
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
            child: const Icon(Icons.check, color: Colors.white, size: 14),
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
            child: const Icon(Icons.group, color: primaryBlue, size: 18),
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

  Widget _buildBillCard(Bill bill) {
    return Container(
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
          // Items section
          if (_items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_items.length} item${_items.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: textGray, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(indent: 20, endIndent: 20),
            ..._items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(color: textDark, fontSize: 14),
                    ),
                  ),
                  Text(
                    'x${item.quantity}',
                    style: const TextStyle(color: textGray, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '฿${item.lineTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )),
            const Divider(indent: 20, endIndent: 20),
          ],
          // Totals section
          Padding(
            padding: const EdgeInsets.all(20),
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
                    Text(
                      '฿${_total.toStringAsFixed(2)}',
                      style: const TextStyle(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonSplit() {
    final members = [
      {'id': '1', 'name': 'You', 'avatar': 'Y'},
    ];

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Per Person',
            style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...members.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dimColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: inputBorder),
                  ),
                  child: Center(
                    child: Text(m['avatar']!, style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(m['name']!, style: const TextStyle(color: textDark, fontSize: 14)),
                ),
                Text(
                  '฿${_total.toStringAsFixed(2)}',
                  style: const TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: textDark, fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                '฿${_total.toStringAsFixed(2)}',
                style: const TextStyle(color: primaryBlue, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => context.go('/bill/${widget.billId}/assign'),
        child: const Text('Assign & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  static const dimColor = Color(0xFFE4E6FF);

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
