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
          onPressed: () => context.go('/bill/${widget.billId}/summary'),
        ),
        title: const Text(
          'Assign',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/bill/${widget.billId}/summary'),
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: assignState.loading
          ? const Center(child: CircularProgressIndicator())
          : assignState.error != null
              ? _buildError(assignState.error!)
              : Column(
                  children: [
                    _buildPayerSection(assignState),
                    _buildMemberBar(assignState),
                    Expanded(child: _buildItemList(assignState)),
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
                  const Text(
                    'Paid by',
                    style: TextStyle(color: AppColors.textGray, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payer?.name ?? 'Tap to set who paid',
                    style: TextStyle(
                      color: payer != null ? AppColors.textDark : AppColors.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit, color: AppColors.textGray, size: 16),
          ],
        ),
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
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Who paid the bill?',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...assignState.members.map((m) {
                final isSelected = m.id == assignState.payerId;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.dimBlue : const Color(0xFFF2F4FC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlue : AppColors.inputBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        m.avatar,
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryBlue : AppColors.textGray,
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
                      ? const Icon(Icons.check_circle, color: AppColors.primaryBlue)
                      : null,
                  onTap: () {
                    ref.read(assignProvider.notifier).setPayer(widget.billId, m.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberBar(AssignState assignState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.inputBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: List.generate(assignState.members.length, (i) {
            final m = assignState.members[i];
            final sel = i == assignState.selectedMemberIndex;
            return GestureDetector(
              onTap: () =>
                  ref.read(assignProvider.notifier).selectMember(i),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.dimBlue : const Color(0xFFF2F4FC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              sel ? AppColors.primaryBlue : AppColors.inputBorder,
                          width: sel ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          m.avatar,
                          style: TextStyle(
                            color:
                                sel ? AppColors.primaryBlue : AppColors.textGray,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.name,
                      style: TextStyle(
                        color: sel ? AppColors.primaryBlue : AppColors.textGray,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
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
          onTap: () => notifier.toggleItem(widget.billId, index),
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
}
