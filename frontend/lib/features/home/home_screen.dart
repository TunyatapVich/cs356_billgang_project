import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../bill/bill_provider.dart';
import '../bill/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputFill = Color(0xFFF2F4FC);
  static const errorRed = Color(0xFFE84545);

  @override
  Widget build(BuildContext context) {
    final billState = ref.watch(billListProvider);

    return Scaffold(
      backgroundColor: bgLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/bill/create'),
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Bill',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Bills',
          style: TextStyle(
            color: textDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add, color: primaryBlue),
            tooltip: 'Join Bill',
            onPressed: () => context.go('/join'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: primaryBlue),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: billState.when(
        loading: () => const SkeletonLoader(),
        error: (error, stackTrace) => _buildError(error),
        data: (bills) => _buildList(bills),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.error_outline, color: errorRed, size: 32),
            ),
            const SizedBox(height: 20),
            const Text('Unable to load bills',
                style: TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: textGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              onPressed: () =>
                  ref.read(billListProvider.notifier).refreshBills(),
              child: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Bill> bills) {
    if (bills.isEmpty) return _buildEmpty();

    final activeBills = bills.where((b) => b.isActive).toList();
    final settledBills = bills.where((b) => !b.isActive).toList();

    return RefreshIndicator(
      color: primaryBlue,
      onRefresh: () => ref.read(billListProvider.notifier).refreshBills(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _buildSummaryStrip(bills.length, activeBills.length),
          const SizedBox(height: 24),
          if (activeBills.isNotEmpty) ...[
            _buildSectionHeader('Active', activeBills.length),
            const SizedBox(height: 12),
            ...activeBills.map((b) => _BillCard(bill: b)),
            const SizedBox(height: 24),
          ],
          if (settledBills.isNotEmpty) ...[
            _buildSectionHeader('Settled', settledBills.length),
            const SizedBox(height: 12),
            ...settledBills.map((b) => _BillCard(bill: b)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(int total, int active) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long,
            label: 'Total Bills',
            value: '$total',
            color: primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            label: 'Active',
            value: '$active',
            color: const Color(0xFF34C759),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: textGray, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E6FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.receipt_long,
                  color: primaryBlue, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'No bills yet',
              style: TextStyle(
                color: textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first bill and start splitting with friends.',
              style: TextStyle(color: textGray, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});

  final Bill bill;

  static const primaryBlue = _HomeScreenState.primaryBlue;
  static const cardWhite = _HomeScreenState.cardWhite;
  static const textDark = _HomeScreenState.textDark;
  static const textGray = _HomeScreenState.textGray;
  static const inputFill = _HomeScreenState.inputFill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/bill/${bill.id}/items'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E6FF),
                    borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(height: 4),
                      Text(
                        '${bill.memberCount} people  ·  ${_formatDate(bill.date)}',
                        style: const TextStyle(color: textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: textGray, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
