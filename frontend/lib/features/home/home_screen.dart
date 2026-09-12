import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar_stack.dart';
import '../auth/auth_provider.dart';
import '../bill/bill_provider.dart';
import '../bill/bill_service.dart';
import '../bill/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateOrJoin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'What would you like to do?',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SheetOption(
              icon: Icons.add,
              iconColor: AppColors.primaryBlue,
              label: 'Create New Bill',
              subtitle: 'Start a new bill with receipt scan or manual entry',
              onTap: () {
                Navigator.pop(context);
                context.go('/bill/new');
              },
            ),
            const SizedBox(height: 12),
            _SheetOption(
              icon: Icons.people_outline,
              iconColor: AppColors.primaryBlue,
              label: 'Join a Bill',
              subtitle: 'Use invite code or scan QR code',
              onTap: () {
                Navigator.pop(context);
                context.go('/join');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billState = ref.watch(billListProvider);
    final user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOrJoin,
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppColors.bgLight,
            elevation: 0,
            pinned: true,
            title: const Text(
              'BillGang',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: UserAvatar(
                    name: user?.displayName,
                    email: user?.email,
                    avatarUrl: user?.avatarUrl,
                    size: AvatarSize.normal,
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.bgLight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textGray,
                  indicatorColor: AppColors.primaryBlue,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Settled'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: billState.when(
          loading: () => const SkeletonLoader(),
          error: (error, stackTrace) => _buildError(error),
          data: (bills) => _buildBillList(bills),
        ),
      ),
    );
  }

  Widget _buildBillList(List<Bill> bills) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildBillSection(bills.where((b) => b.isActive).toList(), isActiveTab: true),
        _buildBillSection(bills.where((b) => !b.isActive).toList(), isActiveTab: false),
      ],
    );
  }

  Widget _buildBillSection(List<Bill> bills, {required bool isActiveTab}) {
    if (bills.isEmpty) return _buildEmpty(isActiveTab: isActiveTab);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: bills.length,
      itemBuilder: (context, index) => _BillCard(
        bill: bills[index],
        onDelete: () async {
          await ref.read(billServiceProvider).deleteBill(bills[index].id);
          ref.read(billListProvider.notifier).refreshBills();
        },
      ),
    );
  }

  Widget _buildEmpty({required bool isActiveTab}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.dimBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.primaryBlue, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              isActiveTab ? 'No active bills' : 'No settled bills',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActiveTab
                  ? 'Start by creating a new bill or join one with your friends.'
                  : 'Bills you settle will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGray, fontSize: 13),
            ),
            if (isActiveTab) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                ),
                onPressed: () => context.go('/bill/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Bill', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
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
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.error_outline, color: AppColors.errorRed, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load bills',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: AppColors.textGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () => ref.read(billListProvider.notifier).refreshBills(),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textGray, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onDelete});

  final Bill bill;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasReceiptImage = bill.receiptImageUrl != null && bill.receiptImageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/bill/${bill.id}/summary'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.dimBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: hasReceiptImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            bill.receiptImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.receipt, color: AppColors.primaryBlue, size: 24),
                          ),
                        )
                      : const Icon(Icons.receipt, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.name,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 14, color: AppColors.textGray),
                          const SizedBox(width: 4),
                          Text(
                            '${bill.memberCount} ${bill.memberCount == 1 ? 'member' : 'members'}',
                            style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textGray),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(bill.date),
                            style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: bill.isActive ? AppColors.selectedGreen : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textGray, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.go('/bill/${bill.id}/items');
                    } else if (value == 'delete') {
                      _showDeleteSheet(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Bill')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Bill', style: TextStyle(color: AppColors.errorRed)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Bill', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${bill.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
