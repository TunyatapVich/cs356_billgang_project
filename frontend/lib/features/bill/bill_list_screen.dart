import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bill_provider.dart';

class BillListScreen extends ConsumerStatefulWidget {
  const BillListScreen({super.key});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  final _searchController = TextEditingController();
  String _keyword = '';

  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputFill = Color(0xFFF2F4FC);
  static const inputBorder = Color(0xFFDCDFEA);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billState = ref.watch(billListProvider);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'All Bills',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: primaryBlue),
            onPressed: () => context.go('/bill/create'),
          ),
        ],
      ),
      body: billState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(error),
        data: (bills) => _buildList(bills),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: primaryBlue, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Unable to load bills',
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            style: const TextStyle(color: textGray, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => ref.read(billListProvider.notifier).refreshBills(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Bill> bills) {
    final keyword = _keyword.toLowerCase();
    final filteredBills = keyword.isEmpty
        ? bills
        : bills.where((bill) {
            return bill.name.toLowerCase().contains(keyword) ||
                bill.inviteCode.toLowerCase().contains(keyword);
          }).toList();

    return RefreshIndicator(
      color: primaryBlue,
      onRefresh: () => ref.read(billListProvider.notifier).refreshBills(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(bills.length),
            const SizedBox(height: 20),
            _buildSearchField(),
            const SizedBox(height: 20),
            const Text(
              'Recent Bills',
              style: TextStyle(
                color: textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredBills.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      itemCount: filteredBills.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => _BillCard(bill: filteredBills[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track your active and finished shared bills.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _keyword = value.trim()),
      decoration: InputDecoration(
        filled: true,
        fillColor: inputFill,
        hintText: 'Search bill name or invite code',
        hintStyle: const TextStyle(color: textGray, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: textGray),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: const [
        SizedBox(height: 110),
        Icon(Icons.receipt_long, color: primaryBlue, size: 44),
        SizedBox(height: 12),
        Text(
          'No bills found',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Create your first bill or try another search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textGray, fontSize: 13),
        ),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});

  final Bill bill;

  static const primaryBlue = _BillListScreenState.primaryBlue;
  static const cardWhite = _BillListScreenState.cardWhite;
  static const textDark = _BillListScreenState.textDark;
  static const textGray = _BillListScreenState.textGray;
  static const inputFill = _BillListScreenState.inputFill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/bill/${bill.id}/items'),
        child: Container(
          padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildMetaRow(),
              const SizedBox(height: 12),
              _buildPercentRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt, color: primaryBlue, size: 22),
        ),
        const SizedBox(width: 14),
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
              const SizedBox(height: 5),
              Text(
                _formatDate(bill.date),
                style: const TextStyle(color: textGray, fontSize: 13),
              ),
            ],
          ),
        ),
        _buildStatusChip(),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: textGray, size: 22),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bill.isActive ? const Color(0xFFE4E6FF) : inputFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _capitalize(bill.status),
        style: TextStyle(
          color: bill.isActive ? primaryBlue : textGray,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        _buildMetaPill(Icons.group_outlined, '${bill.memberCount} people'),
        const SizedBox(width: 8),
        _buildMetaPill(Icons.confirmation_number_outlined, bill.inviteCode),
      ],
    );
  }

  Widget _buildMetaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textGray, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: textGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentRow() {
    return Row(
      children: [
        Expanded(
          child: _buildPercentTile('Service', bill.serviceChargePercent),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildPercentTile('VAT', bill.vatPercent)),
      ],
    );
  }

  Widget _buildPercentTile(String label, double? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textGray, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value == null ? '-' : '${value.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: primaryBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

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
