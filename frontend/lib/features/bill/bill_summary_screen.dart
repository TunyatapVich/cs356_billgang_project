import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/socket/socket_client.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar_stack.dart';
import '../../core/widgets/image_lightbox.dart';
import '../../core/widgets/screen_app_bar.dart';
import '../auth/auth_provider.dart';
import '../settlement/payment_service.dart';
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

  Map<String, dynamic>? _bill;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _perPerson = [];
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _payments = [];
  final Set<String> _expandedPersons = {};

  bool _loading = true;
  bool _markingPaid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    if (type == 'payer_set' || type == 'payment_confirmed' || type == 'payment_created' || type == 'bill_updated') {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final billService = ref.read(billServiceProvider);
      final paymentService = ref.read(paymentServiceProvider);

      final results = await Future.wait<dynamic>([
        billService.getBill(widget.billId),
        billService.getDebts(widget.billId),
        paymentService.listByBill(widget.billId),
      ]);

      final billData = results[0] as Map<String, dynamic>;
      final debtsData = results[1] as Map<String, dynamic>;
      final paymentsData = results[2] as Map<String, dynamic>;

      final bill = billData['bill'] as Map<String, dynamic>;
      final items = (billData['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final members = (billData['members'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final perPerson = (debtsData['per_person'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final transfers = (debtsData['transfers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final payments = (paymentsData['payments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;
      setState(() {
        _bill = bill;
        _items = items;
        _members = members;
        _perPerson = perPerson;
        _transfers = transfers;
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _payerId => _bill?['paid_by']?.toString() ?? _bill?['created_by']?.toString() ?? '';

  String _getMemberName(String userId) {
    final member = _members.firstWhere(
      (m) => m['user_id'].toString() == userId,
      orElse: () => {'user': {'display_name': 'Member'}},
    );
    final user = member['user'] as Map<String, dynamic>? ?? {};
    return getShortName(user['display_name'] as String?, user['email'] as String?);
  }

  Map<String, dynamic>? _getMemberUser(String userId) {
    final member = _members.firstWhere(
      (m) => m['user_id'].toString() == userId,
      orElse: () => {},
    );
    return member['user'] as Map<String, dynamic>?;
  }

  double get _subtotal => _items.fold<double>(
        0.0,
        (sum, item) => sum + (((item['quantity'] as num?)?.toInt() ?? 1) * ((item['unit_price'] as num?)?.toDouble() ?? 0.0)),
      );

  double get _servicePercent => (_bill?['service_charge_pct'] as num?)?.toDouble() ?? 0.0;
  double get _vatPercent => (_bill?['vat_pct'] as num?)?.toDouble() ?? 0.0;

  double get _service => _subtotal * (_servicePercent / 100);
  double get _vat => (_subtotal + _service) * (_vatPercent / 100);
  double get _total => _subtotal + _service + _vat;

  Future<void> _claimPayer() async {
    final currentUserId = ref.read(authProvider).value?.id;
    if (currentUserId == null) return;
    try {
      await ref.read(billServiceProvider).setPayer(billId: widget.billId, payerId: currentUserId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set payer: $e')));
      }
    }
  }

  Future<void> _markBillPaid() async {
    setState(() => _markingPaid = true);
    try {
      await ref.read(billServiceProvider).markBillPaid(widget.billId);
      ref.read(billListProvider.notifier).refreshBills();
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark bill as paid: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  void _showConfirmLocalTransfer(Map<String, dynamic> transfer) {
    final fromId = transfer['from_user_id'].toString();
    final toId = transfer['to_user_id'].toString();
    final amount = (transfer['amount'] as num?)?.toDouble() ?? 0.0;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Confirm Payment',
                  style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textGray),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Text(
              'Mark as Paid?',
              style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dimBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount to pay', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                      Text(
                        '฿${amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.primaryBlue, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_getMemberName(fromId), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('➔', style: TextStyle(color: AppColors.textGray)),
                      Text(_getMemberName(toId), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.inputBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(billServiceProvider).confirmLocalPayment(
                          billId: widget.billId,
                          fromUserId: fromId,
                          toUserId: toId,
                        );
                        _loadData();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to confirm payment: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Confirm Paid', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShareModal() {
    final billName = _bill?['name']?.toString() ?? 'Bill';
    final sb = StringBuffer();
    sb.writeln('🧾 $billName — BillGang');
    sb.writeln('Total: ฿${_total.toStringAsFixed(2)}');
    sb.writeln('--------------------');
    for (final p in _perPerson) {
      final uid = p['user_id'].toString();
      final name = _getMemberName(uid);
      final owed = (p['owed'] as num?)?.toDouble() ?? 0.0;
      sb.writeln('• $name: ฿${owed.toStringAsFixed(2)}');
    }
    final payer = _members.firstWhere(
      (m) => m['user_id'].toString() == _payerId,
      orElse: () => {},
    );
    final payerUser = payer['user'] as Map<String, dynamic>?;
    final promptpay = payerUser?['promptpay_number'] as String?;
    if (promptpay != null && promptpay.isNotEmpty) {
      sb.writeln('--------------------');
      sb.writeln('PromptPay: $promptpay');
    }

    final shareText = sb.toString();

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share Bill Summary',
                  style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textGray), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: SelectableText(
                shareText,
                style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDark),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shareText));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Summary copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('Copy to Clipboard', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: ScreenAppBar(title: 'Bill Summary', backHref: '/'),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    if (_error != null && _bill == null) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: const ScreenAppBar(title: 'Bill Summary', backHref: '/'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDark, fontSize: 15)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final status = _bill?['status']?.toString() ?? 'active';
    final isSettled = status == 'settled';
    final receiptUrl = _bill?['receipt_image_url'] as String?;
    final billName = _bill?['name']?.toString() ?? 'Bill Summary';
    final currentUserId = ref.read(authProvider).value?.id;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: ScreenAppBar(
        title: 'Bill Summary',
        backHref: '/',
        action: IconButton(
          icon: const Icon(Icons.share_outlined, color: AppColors.primaryBlue),
          onPressed: _showShareModal,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settled Banner
            if (isSettled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.successGreen, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All payments have been settled',
                        style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Card 1: Bill & Items Breakdown
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.inputBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      if (receiptUrl != null && receiptUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () => ImageLightbox.show(context, receiptUrl),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: AppColors.dimBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(receiptUrl, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              billName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_items.length} items',
                              style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? AppColors.successGreen.withValues(alpha: 0.1)
                              : AppColors.dimBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSettled)
                              const Icon(Icons.check, color: AppColors.successGreen, size: 13)
                            else
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            const SizedBox(width: 5),
                            Text(
                              isSettled ? 'Settled' : 'Active',
                              style: TextStyle(
                                color: isSettled ? AppColors.successGreen : AppColors.primaryBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Items list
                  ..._items.map((item) {
                    final name = item['name']?.toString() ?? 'Item';
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    final price = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                    final lineTotal = qty * price;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: name,
                                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: ' ×$qty',
                                    style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '฿${lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Subtotal & Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                      Text('฿${_subtotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                    ],
                  ),
                  if (_service > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Service Charge ($_servicePercent%)', style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
                        Text('฿${_service.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                      ],
                    ),
                  ],
                  if (_vat > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('VAT ($_vatPercent%)', style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
                        Text('฿${_vat.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '฿${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Action buttons
                  Row(
                    children: [
                      if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ImageLightbox.show(context, receiptUrl),
                            icon: const Icon(Icons.receipt_long, size: 16),
                            label: const Text('View Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textDark,
                              side: const BorderSide(color: AppColors.inputBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showShareModal,
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side: const BorderSide(color: AppColors.primaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Card 2: Breakdown by Person
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Breakdown by Person',
                            style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text('${_perPerson.length} members', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.dimBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_circle_outlined, size: 13, color: AppColors.primaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  'Payer: ${_getMemberName(_payerId)}',
                                  style: const TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (_payerId.isEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _claimPayer,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primaryBlue),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('I Paid', style: TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (!isSettled && _transfers.isEmpty && currentUserId == _bill?['created_by']) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _markingPaid ? null : _markBillPaid,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: _markingPaid
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Mark Bill as Paid'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Members list
                  ..._perPerson.map((person) {
                    final uid = person['user_id'].toString();
                    final user = person['user'] as Map<String, dynamic>? ?? _getMemberUser(uid) ?? {};
                    final name = getShortName(user['display_name'] as String?, user['email'] as String?);
                    final isPayer = uid == _payerId;
                    final owed = (person['owed'] as num?)?.toDouble() ?? 0.0;

                    // Payment status
                    final payment = _payments.firstWhere(
                      (p) => p['from_user_id'].toString() == uid,
                      orElse: () => {},
                    );
                    final paymentStatus = payment['status']?.toString();
                    final isPaid = isPayer || paymentStatus == 'confirmed';
                    final isPending = paymentStatus == 'pending';

                    final isExpanded = _expandedPersons.contains(uid);

                    // Assigned items for this person
                    final personItems = _items.where((item) {
                      final assigns = (item['item_assigns'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                      return assigns.any((a) => a['user_id'].toString() == uid && ((a['assigned_quantity'] as num?)?.toInt() ?? 1) > 0);
                    }).toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              UserAvatar(
                                name: user['display_name'] as String?,
                                email: user['email'] as String?,
                                avatarUrl: user['avatar_url'] as String?,
                                size: AvatarSize.small,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          uid == currentUserId ? '$name (You)' : name,
                                          style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        if (isPayer) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.dimBlue,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Payer', style: TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (personItems.isNotEmpty)
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedPersons.remove(uid);
                                            } else {
                                              _expandedPersons.add(uid);
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('${personItems.length} items', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                                              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: AppColors.textGray),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '฿${owed.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? AppColors.successGreen.withValues(alpha: 0.1)
                                          : isPending
                                              ? AppColors.dimBlue
                                              : Colors.amber.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isPaid
                                          ? 'Paid'
                                          : isPending
                                              ? 'Payment pending'
                                              : 'Pending',
                                      style: TextStyle(
                                        color: isPaid
                                            ? AppColors.successGreen
                                            : isPending
                                                ? AppColors.primaryBlue
                                                : Colors.amber.shade900,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (isExpanded && personItems.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            ...personItems.map((item) {
                              final itemName = item['name']?.toString() ?? 'Item';
                              final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                              final assigns = (item['item_assigns'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                              final assign = assigns.firstWhere((a) => a['user_id'].toString() == uid, orElse: () => {});
                              final qty = (assign['assigned_quantity'] as num?)?.toInt() ?? 1;
                              final portionPrice = qty * unitPrice;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('$itemName ×$qty', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                                    Text('฿${portionPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 12)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Card 3: Pending Payments / Debt Transfers
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Payments',
                    style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('Direct debt settlements', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                  const SizedBox(height: 14),
                  if (_transfers.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.dimBlue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSettled ? 'All settled' : 'No transfers needed.',
                        style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    ..._transfers.map((t) {
                      final fromId = t['from_user_id'].toString();
                      final toId = t['to_user_id'].toString();
                      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                      final isMine = fromId == currentUserId;
                      final isLocalGuest = _members.any((m) => m['user_id'].toString() == fromId && m['role'] == 'guest');
                      final isCreator = currentUserId == _bill?['created_by'];

                      // Payment check
                      final pmt = _payments.firstWhere(
                        (p) => p['from_user_id'].toString() == fromId && p['to_user_id'].toString() == toId,
                        orElse: () => {},
                      );
                      final isConfirmed = pmt['status'] == 'confirmed';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              name: _getMemberName(fromId),
                              avatarUrl: _getMemberUser(fromId)?['avatar_url'] as String?,
                              size: AvatarSize.small,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getMemberName(fromId), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('Transfer to ${_getMemberName(toId)}', style: const TextStyle(color: AppColors.textGray, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (isConfirmed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Paid', style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            else if (isLocalGuest && isCreator)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () => _showConfirmLocalTransfer(t),
                                child: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                            else if (isMine)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                onPressed: () {
                                  context.go(
                                    '/bill/${widget.billId}/paid/$toId/${amount.toInt()}?amount=${amount.toStringAsFixed(2)}&name=${Uri.encodeComponent(_getMemberName(toId))}&rawAmount=${amount.toStringAsFixed(2)}',
                                  );
                                },
                                icon: const Icon(Icons.arrow_forward, size: 14),
                                label: Text('Pay ฿${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            else
                              Text('฿${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textGray)),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
