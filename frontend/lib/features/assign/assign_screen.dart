import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'assign_provider.dart';

class AssignScreen extends ConsumerStatefulWidget {
  const AssignScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends ConsumerState<AssignScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(assignProvider.notifier).loadBill(widget.billId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignState = ref.watch(assignProvider);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => context.go('/bill/${widget.billId}/items'),
        ),
        title: const Text(
          'Assign',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [],
      ),
      body: assignState.loading
          ? const Center(child: CircularProgressIndicator())
          : assignState.error != null
              ? _buildError(assignState.error!)
              : Column(
                  children: [
                    _buildPayerSection(assignState),
                    const SizedBox(height: 12),
                    _buildMemberBar(assignState),
                    const SizedBox(height: 12),
                    Expanded(child: _buildItemList(assignState)),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 42),
          const SizedBox(height: 12),
          Text(
            error.toString(),
            style: const TextStyle(color: AppColors.textGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                ref.read(assignProvider.notifier).loadBill(widget.billId),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showPayerPicker(AssignState assignState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Who paid the bill?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...assignState.members.map((m) {
                final isSelected = m.id == assignState.payerId;
                return ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue : AppColors.dimBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        m.avatar,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    m.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primaryBlue)
                      : null,
                  onTap: () async {
                    try {
                      await ref.read(assignProvider.notifier).setPayer(widget.billId, m.id);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update payer: $e')),
                        );
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayerSection(AssignState assignState) {
    final payer = assignState.payerId != null
        ? assignState.members.where((m) => m.id == assignState.payerId).firstOrNull
        : null;

    return GestureDetector(
      onTap: () => _showPayerPicker(assignState),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.receipt, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid by',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payer?.name ?? 'Tap to select',
                    style: TextStyle(
                      color: payer != null ? AppColors.textDark : AppColors.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textGray,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberBar(AssignState assignState) {
    if (assignState.members.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_outlined, color: AppColors.textGray, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Invite members to assign items',
                style: TextStyle(color: AppColors.textGray, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/bill/${widget.billId}/invite'),
              child: const Text('Invite', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Assign to', style: TextStyle(color: AppColors.textGray, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(assignState.members.length, (i) {
                final m = assignState.members[i];
                final sel = i == assignState.selectedMemberIndex;
                final isPayer = m.id == assignState.payerId;
                return GestureDetector(
                  onTap: () => ref.read(assignProvider.notifier).selectMember(i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: sel ? AppColors.dimBlue : AppColors.inputFill,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel ? AppColors.primaryBlue : AppColors.inputBorder,
                                  width: sel ? 2.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(m.avatar, style: TextStyle(
                                  color: sel ? AppColors.primaryBlue : AppColors.textGray,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                )),
                              ),
                            ),
                            if (isPayer)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                  child: const Icon(Icons.star, color: Colors.white, size: 10),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(m.name, style: TextStyle(
                          color: sel ? AppColors.primaryBlue : AppColors.textGray,
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(AssignState assignState) {
    final notifier = ref.read(assignProvider.notifier);

    if (assignState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              color: AppColors.textGray.withValues(alpha: 0.4),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text('No items yet',
                style: TextStyle(color: AppColors.textGray)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: assignState.items.length,
      itemBuilder: (context, index) {
        final item = assignState.items[index];
        final sel = notifier.isItemSelected(item);
        return GestureDetector(
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final ok = await notifier.toggleItem(widget.billId, index);
              if (!ok && mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Select a member first'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (_) {
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update item. Please try again.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFE8FDF0) : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel
                    ? AppColors.selectedGreen.withValues(alpha: 0.4)
                    : AppColors.inputBorder,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.selectedGreen : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel
                          ? AppColors.selectedGreen
                          : AppColors.textGray.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child:
                      sel ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: sel ? AppColors.selectedGreen : AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'x${item.quantity}  ·  ฿${item.unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppColors.textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '฿${item.lineTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: sel ? AppColors.selectedGreen : AppColors.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/bill/${widget.billId}/invite'),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => context.go('/bill/${widget.billId}/summary'),
              child: const Text('View Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
