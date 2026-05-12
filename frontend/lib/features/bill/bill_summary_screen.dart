import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/socket/socket_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_provider.dart';
import 'bill_provider.dart';
import 'bill_service.dart';

class BillSummaryScreen extends ConsumerStatefulWidget {
  const BillSummaryScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends ConsumerState<BillSummaryScreen> {
  SocketClient? _socket;
  StreamSubscription? _socketSub;

  Bill? _bill;
  List<BillItem> _items = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _perPerson = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadBill();
    _connectSocket();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final token = await TokenStorage.read() ?? '';
    _socket = SocketClient();
    _socket!.connect(widget.billId, token);
    _socketSub = _socket!.stream.listen(_handleSocketEvent);
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'payer_set') {
      final newPayerId = event['paid_by'] as String?;
      if (newPayerId != null && mounted) {
        setState(() {
          _bill = _bill?.copyWith(paidBy: newPayerId);
        });
      }
    } else if (type == 'bill_updated') {
      _loadBill();
    }
  }

  Future<void> _loadBill() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(billServiceProvider);
      final results = await Future.wait<Map<String, dynamic>>([
        service.getBill(widget.billId),
        service.getDebts(widget.billId),
      ]);

      final billData = results[0];
      final debtsData = results[1];

      final bill = Bill.fromJson(billData['bill'] as Map<String, dynamic>);
      final rawItems = (billData['items'] as List<dynamic>?) ?? [];
      final items = rawItems.cast<Map<String, dynamic>>().map(BillItem.fromJson).toList();
      final members = (billData['members'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final perPerson = (debtsData['per_person'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;
      setState(() {
        _bill = bill;
        _items = items;
        _members = members;
        _perPerson = perPerson;
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

  String get _payerName {
    if (_bill?.paidBy == null) return 'User';
    final member = _members.where((m) => m['user_id'] == _bill!.paidBy).firstOrNull;
    final user = member?['user'] as Map<String, dynamic>?;
    return (user?['display_name'] ?? user?['email'] ?? 'User') as String;
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get _service => _subtotal * ((_bill?.serviceChargePercent ?? 0) / 100);
  double get _vat => _subtotal * ((_bill?.vatPercent ?? 0) / 100);
  double get _total => _subtotal + _service + _vat;

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
          'Bill Summary',
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
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 42),
          const SizedBox(height: 12),
          Text(_error.toString(), style: const TextStyle(color: AppColors.textGray)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
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

  Widget _buildMemberRow(Bill bill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            bill.name,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _formatDate(bill.date),
            style: const TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Bill bill) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
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
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_items.length} item${_items.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  ..._items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(color: AppColors.textDark, fontSize: 13),
                          ),
                        ),
                        Text(
                          'x${item.quantity}',
                          style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '฿${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
                  _buildDashedDivider(),
                ],
              ),
            ),
          ],
          // Totals section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTotalRow('Subtotal', _subtotal, isBold: false),
                const SizedBox(height: 6),
                _buildTotalRow('Service ${bill.serviceChargePercent ?? 0}%', _service, isBold: false),
                const SizedBox(height: 6),
                _buildTotalRow('VAT ${bill.vatPercent ?? 0}%', _vat, isBold: false),
                const SizedBox(height: 12),
                _buildDashedDivider(),
                const SizedBox(height: 12),
                _buildTotalRow('Total', _total, isBold: true, isTotal: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Row(
      children: List.generate(
        30,
        (index) => Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textGray.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.textDark : AppColors.textGray,
            fontSize: isTotal ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '฿${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isTotal ? AppColors.primaryBlue : AppColors.textDark,
            fontSize: isTotal ? 17 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonSplit() {
    final currentUserId = ref.read(authProvider).value?.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
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
            style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_perPerson.isEmpty)
            const Text('No assignments yet', style: TextStyle(color: AppColors.textGray, fontSize: 14))
          else
            ..._perPerson.map((p) {
              final user = p['user'] as Map<String, dynamic>? ?? {};
              final displayName = (user['display_name'] ?? user['email'] ?? 'Unknown') as String;
              final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
              final owed = (p['owed'] as num?)?.toDouble() ?? 0.0;
              final isMe = p['user_id'] == currentUserId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primaryBlue : AppColors.dimBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: isMe ? AppColors.primaryBlue : AppColors.inputBorder),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: isMe ? Colors.white : AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isMe ? '$displayName (You)' : displayName,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '฿${owed.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.primaryBlue, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
              Text(
                '฿${_total.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.primaryBlue, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }


  double get _myOwedAmount {
    final currentUserId = ref.read(authProvider).value?.id;
    if (currentUserId == null || _perPerson.isEmpty) return _total;
    final mine = _perPerson.where((p) => p['user_id'] == currentUserId).firstOrNull;
    return (mine?['owed'] as num?)?.toDouble() ?? 0.0;
  }

  Widget _buildPayButton() {
    final payerId = _bill?.paidBy;
    final currentUserId = ref.read(authProvider).value?.id;
    final isCurrentUserPayer = payerId != null && payerId == currentUserId;
    final myOwed = _myOwedAmount;
    final canPay = payerId != null && !isCurrentUserPayer && myOwed > 0;

    String label;
    if (payerId == null) {
      label = 'No Payer Set';
    } else if (isCurrentUserPayer) {
      label = 'You paid this bill';
    } else if (myOwed <= 0) {
      label = 'Nothing to pay';
    } else {
      label = 'Pay ฿${myOwed.toStringAsFixed(2)}';
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canPay ? AppColors.primaryBlue : AppColors.textGray,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: canPay
            ? () => context.go('/bill/${widget.billId}/paid/$payerId/${myOwed.toInt()}?amount=${myOwed.toStringAsFixed(2)}&name=${Uri.encodeComponent(_payerName)}&rawAmount=${myOwed.toStringAsFixed(2)}')
            : null,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
