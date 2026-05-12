import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'bill_provider.dart';
import 'bill_service.dart';

class EditBillScreen extends ConsumerStatefulWidget {
  const EditBillScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends ConsumerState<EditBillScreen> {

  Bill? _bill;
  List<BillItem> _items = [];
  List<_Member> _members = [];
  int _selectedMemberIndex = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ref.read(billServiceProvider).getBill(widget.billId);
      _bill = Bill.fromJson(data);
      final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
      _items = itemsRaw.cast<Map<String, dynamic>>().map((itemJson) {
        final assigns = (itemJson['item_assigns'] as List<dynamic>?) ?? [];
        final assignedTo = assigns.map((a) => (a['user_id'] ?? a['userId'] ?? '') as String).toList();
        return BillItem.fromJson(itemJson).copyWith(assignedTo: assignedTo);
      }).toList();

      final membersRaw = (data['members'] as List<dynamic>?) ?? [];
      _members = membersRaw.cast<Map<String, dynamic>>().map((m) {
        final user = m['user'] as Map<String, dynamic>? ?? {};
        final displayName = (user['display_name'] ?? user['email'] ?? 'U') as String;
        return _Member(
          id: (m['user_id'] ?? user['id'] ?? '').toString(),
          name: displayName,
          avatar: displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        );
      }).toList();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  void _toggleItem(int itemIndex) async {
    final memberId = _members.isEmpty ? '' : _members[_selectedMemberIndex].id;
    if (memberId.isEmpty) return;
    final item = _items[itemIndex];
    final assigned = item.assignedTo ?? [];
    final isCurrentlyAssigned = assigned.contains(memberId);

    setState(() {
      if (isCurrentlyAssigned) {
        _items[itemIndex] = item.copyWith(
          assignedTo: assigned.where((id) => id != memberId).toList(),
        );
      } else {
        _items[itemIndex] = item.copyWith(assignedTo: [...assigned, memberId]);
      }
    });

    try {
      if (isCurrentlyAssigned) {
        await ref.read(billServiceProvider).unassignItem(
          billId: widget.billId, itemId: item.id, userId: memberId);
      } else {
        await ref.read(billServiceProvider).assignItem(
          billId: widget.billId, itemId: item.id, userId: memberId);
      }
    } catch (_) {
      setState(() => _items[itemIndex] = item);
    }
  }

  bool _isItemSelected(BillItem item) =>
      item.assignedTo?.contains(_members.isEmpty ? '' : _members[_selectedMemberIndex].id) ?? false;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  String get _payerName {
    if (_bill?.paidBy == null) return 'User';
    final member = _members.where((m) => m.id == _bill!.paidBy).firstOrNull;
    return member?.name ?? 'User';
  }
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
        title: Text(
          _bill?.name ?? 'Edit Bill',
          style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: () => context.go('/bill/${widget.billId}/summary'),
              child: const Text(
                'View Summary',
                style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
        ],
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
            onPressed: _loadData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBillHeader(),
                const SizedBox(height: 16),
                _buildMembersBar(),
                const SizedBox(height: 16),
                _buildItemsList(),
                const SizedBox(height: 16),
                _buildTotalsCard(),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBillHeader() {
    final bill = _bill!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dimBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.primaryBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.name,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_members.length} member${_members.length == 1 ? '' : 's'}  ·  ${_formatDate(bill.date)}',
                  style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bill.isActive
                  ? const Color(0xFF34C759).withValues(alpha: 0.1)
                  : AppColors.textGray.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bill.isActive ? 'Active' : 'Settled',
              style: TextStyle(
                color: bill.isActive ? const Color(0xFF34C759) : AppColors.textGray,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersBar() {
    if (_members.isEmpty) {
      return Container(
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
              children: List.generate(_members.length, (i) {
                final m = _members[i];
                final sel = i == _selectedMemberIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMemberIndex = i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
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

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primaryBlue, size: 40),
            const SizedBox(height: 12),
            const Text('No items yet', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Add items to start assigning', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/bill/${widget.billId}/items'),
              icon: const Icon(Icons.add, color: AppColors.primaryBlue, size: 18),
              label: const Text('Add Items', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Items', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/bill/${widget.billId}/items'),
                  icon: const Icon(Icons.add, color: AppColors.primaryBlue, size: 16),
                  label: const Text('Add', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final sel = _isItemSelected(item);
            return InkWell(
              onTap: _members.isEmpty ? null : () => _toggleItem(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFE8FDF0) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.selectedGreen : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? AppColors.selectedGreen : AppColors.textGray.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: TextStyle(
                            color: sel ? AppColors.selectedGreen : AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                          const SizedBox(height: 2),
                          Text('x${item.quantity}  ·  ฿${item.unitPrice.toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('฿${item.lineTotal.toStringAsFixed(0)}', style: TextStyle(
                      color: sel ? AppColors.selectedGreen : AppColors.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(color: AppColors.textGray, fontSize: 14)),
              Text('฿${_subtotal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Service ${_bill?.serviceChargePercent ?? 0}%', style: const TextStyle(color: AppColors.textGray, fontSize: 14)),
              Text('฿${_service.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('VAT ${_bill?.vatPercent ?? 0}%', style: const TextStyle(color: AppColors.textGray, fontSize: 14)),
              Text('฿${_vat.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('฿${_total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
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
              onPressed: _bill?.paidBy == null
                  ? null
                  : () => context.go('/bill/${widget.billId}/paid/${_bill!.paidBy}/${_total.toInt()}?amount=${_total.toStringAsFixed(2)}&name=${Uri.encodeComponent(_payerName)}'),
              child: Text(_bill?.paidBy == null ? 'No Payer Set' : 'Go to Pay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _Member {
  final String id;
  final String name;
  final String avatar;
  const _Member({required this.id, required this.name, required this.avatar});
}
