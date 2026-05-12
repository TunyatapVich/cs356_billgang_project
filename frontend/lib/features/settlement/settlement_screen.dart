import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'payment_service.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  Map<String, dynamic>? _debtData;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final debts = await ref.read(paymentServiceProvider).getDebts(widget.billId);
      if (!mounted) return;
      setState(() {
        _debtData = {'debts': debts};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _loading = false; });
    }
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
          onPressed: () => context.go('/bill/${widget.billId}/edit'),
        ),
        title: const Text(
          'Settlement',
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
            onPressed: _loadDebts,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final debts = (_debtData?['debts'] as List<dynamic>?) ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          _buildHero(),
          const SizedBox(height: 24),
          _buildDebtList(debts.cast<Map<String, dynamic>>()),
        ],
      ),
    );
  }

  Widget _buildHero() {
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
          child: const Icon(Icons.account_balance_wallet, color: AppColors.primaryBlue, size: 36),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.24),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.currency_exchange, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDebtList(List<Map<String, dynamic>> debts) {
    if (debts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF34C759), size: 48),
            SizedBox(height: 12),
            Text(
              'All settled!',
              style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'No outstanding balances',
              style: TextStyle(color: AppColors.textGray, fontSize: 14),
            ),
          ],
        ),
      );
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Who owes who',
              style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ...debts.asMap().entries.map((entry) {
            final index = entry.key;
            final debt = entry.value;
            return _buildDebtRow(debt, index % 2 == 1);
          }),
        ],
      ),
    );
  }

  Widget _buildDebtRow(Map<String, dynamic> debt, bool alt) {
    final fromUser = debt['from_user'] as Map<String, dynamic>?;
    final toUser = debt['to_user'] as Map<String, dynamic>?;
    final amount = (debt['amount'] as num?)?.toDouble() ?? 0.0;
    final fromName = (fromUser?['display_name'] ?? fromUser?['email'] ?? 'Unknown') as String;
    final toName = (toUser?['display_name'] ?? toUser?['email'] ?? 'Unknown') as String;
    final toUserId = (toUser?['id'] ?? '') as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: alt ? AppColors.inputFill.withValues(alpha: 0.3) : Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8E8),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                fromName.isNotEmpty ? fromName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromName,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'pays ',
                      style: TextStyle(color: AppColors.textGray.withValues(alpha: 0.8), fontSize: 12),
                    ),
                    Text(
                      toName,
                      style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${amount.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.errorRed, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => context.go('/bill/${widget.billId}/promptpay/$toUserId/${amount.toStringAsFixed(2)}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pay',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
