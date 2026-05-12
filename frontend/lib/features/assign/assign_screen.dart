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

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final memberId = details.data['id'] as String;
        ref.read(assignProvider.notifier).setPayer(widget.billId, memberId);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isHovering ? const Color(0xFFFFF3CD) : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering ? Colors.amber : AppColors.inputBorder,
              width: isHovering ? 2 : 1,
            ),
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
                      isHovering ? 'Drop to set payer' : 'Paid by',
                      style: TextStyle(
                        color: isHovering ? Colors.amber.shade700 : AppColors.textGray,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payer?.name ?? 'Drag member here',
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
                Icons.drag_indicator,
                color: isHovering ? Colors.amber : AppColors.textGray,
                size: 20,
              ),
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
            final isPayer = m.id == assignState.payerId;
            return LongPressDraggable<Map<String, dynamic>>(
              data: {'id': m.id, 'name': m.name, 'avatar': m.avatar},
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.dimBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryBlue, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: Text(m.avatar, style: const TextStyle(color: AppColors.primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _memberAvatar(m, sel, isPayer),
              ),
              onDragStarted: () => ref.read(assignProvider.notifier).selectMember(i),
              child: GestureDetector(
                onTap: () => ref.read(assignProvider.notifier).selectMember(i),
                child: _memberAvatar(m, sel, isPayer),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _memberAvatar(AssignMember m, bool sel, bool isPayer) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: sel ? AppColors.dimBlue : const Color(0xFFF2F4FC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPayer ? Colors.amber : (sel ? AppColors.primaryBlue : AppColors.inputBorder),
                    width: isPayer ? 2.5 : (sel ? 2.5 : 1),
                  ),
                ),
                child: Center(
                  child: Text(
                    m.avatar,
                    style: TextStyle(
                      color: sel ? AppColors.primaryBlue : AppColors.textGray,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (isPayer)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, color: Colors.white, size: 12),
                  ),
                ),
            ],
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
