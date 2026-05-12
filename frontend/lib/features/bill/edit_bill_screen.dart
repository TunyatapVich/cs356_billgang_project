import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/socket/socket_client.dart';
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
  String? _payerId; // real-time payer from socket
  SocketClient? _socket;
  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socket?.disconnect();
    super.dispose();
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
      _connectSocket(widget.billId);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _loading = false; });
    }
  }

  void _connectSocket(String billId) {
    _socketSub?.cancel();
    _socket?.disconnect();
    _socket = SocketClient();
    _socket!.connect(billId, '');
    _socket!.stream.listen(_handleSocketEvent);
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final itemId = event['item_id'] as String?;
    final userId = event['user_id'] as String?;
    if (itemId == null || userId == null) return;
    if (!mounted) return;

    switch (type) {
      case 'item_assigned':
        _applyAssign(itemId, userId);
        break;
      case 'item_unassigned':
        _applyUnassign(itemId, userId);
        break;
      case 'payer_set':
        final newPayerId = event['paid_by'] as String?;
        if (newPayerId != null) setState(() => _payerId = newPayerId);
        break;
    }
  }

  void _applyAssign(String itemId, String userId) {
    setState(() {
      _items = _items.map((item) {
        if (item.id != itemId) return item;
        final current = item.assignedTo ?? [];
        if (current.contains(userId)) return item;
        return item.copyWith(assignedTo: [...current, userId]);
      }).toList();
    });
  }

  void _applyUnassign(String itemId, String userId) {
    setState(() {
      _items = _items.map((item) {
        if (item.id != itemId) return item;
        final current = item.assignedTo ?? [];
        if (!current.contains(userId)) return item;
        return item.copyWith(assignedTo: current.where((id) => id != userId).toList());
      }).toList();
    });
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
        actions: const [],
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
                _buildPayerSection(),
                const SizedBox(height: 12),
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

  void _showPayerPicker() {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 16),
              ..._members.map((m) {
                final isSelected = m.id == (_payerId ?? _bill?.paidBy);
                return ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue : AppColors.dimBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(m.avatar, style: TextStyle(color: isSelected ? Colors.white : AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  title: Text(m.name, style: TextStyle(
                    color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                  onTap: () {
                    ref.read(billServiceProvider).setPayer(billId: widget.billId, payerId: m.id);
                    setState(() => _payerId = m.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayerSection() {
    final effectivePayerId = _payerId ?? _bill?.paidBy;
    final payer = effectivePayerId != null
        ? _members.where((m) => m.id == effectivePayerId).firstOrNull
        : null;
    return GestureDetector(
      onTap: _members.isEmpty ? null : _showPayerPicker,
      child: Container(
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
                  const Text('Paid by', style: TextStyle(color: AppColors.textGray, fontSize: 11)),
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
            if (_members.isNotEmpty) Icon(Icons.chevron_right, color: AppColors.textGray, size: 20),
          ],
        ),
      ),
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
              onPressed: _loading ? null : () => context.go('/bill/${widget.billId}/summary'),
              child: const Text('View Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
