import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/avatar_stack.dart';
import '../../core/widgets/screen_app_bar.dart';
import '../auth/auth_provider.dart';
import '../bill/bill_service.dart';

class AssignScreen extends ConsumerStatefulWidget {
  const AssignScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends ConsumerState<AssignScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _members = [];

  String _selectedUserId = '';
  String? _payerId;

  // itemId -> (userId -> quantity)
  final Map<String, Map<String, int>> _draftAllocations = {};

  // For multi-quantity item splitting modal
  Map<String, dynamic>? _splitItem;
  Map<String, int> _itemModalAllocations = {};

  // Add person modal
  final _personNameController = TextEditingController();
  bool _addingPerson = false;
  bool _savingBill = false;

  @override
  void initState() {
    super.initState();
    _loadBillDetails();
  }

  @override
  void dispose() {
    _personNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBillDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final billService = ref.read(billServiceProvider);
      final data = await billService.getBill(widget.billId);

      final bill = data['bill'] as Map<String, dynamic>;
      final rawItems = (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final rawMembers = (data['members'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      _draftAllocations.clear();
      final memberIds = rawMembers.map((m) => m['user_id'].toString()).toList();

      for (final item in rawItems) {
        final itemId = item['id'].toString();
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        final assigns = (item['item_assigns'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        final itemMap = <String, int>{};
        final hasExplicit = assigns.any((a) => a['assigned_quantity'] != null);

        if (hasExplicit) {
          for (final a in assigns) {
            final uid = a['user_id'].toString();
            itemMap[uid] = (a['assigned_quantity'] as num?)?.toInt() ?? 0;
          }
        } else if (assigns.isNotEmpty) {
          final assignedUserIds = assigns.map((a) => a['user_id'].toString()).toSet().toList();
          final base = quantity ~/ assignedUserIds.length;
          final rem = quantity % assignedUserIds.length;
          for (int i = 0; i < assignedUserIds.length; i++) {
            itemMap[assignedUserIds[i]] = base + (i < rem ? 1 : 0);
          }
        }

        // Ensure all members have at least 0
        for (final mid in memberIds) {
          itemMap.putIfAbsent(mid, () => 0);
        }

        _draftAllocations[itemId] = itemMap;
      }

      final payer = bill['paid_by']?.toString() ?? bill['created_by']?.toString();

      final currentUserId = ref.read(authProvider).value?.id;
      String selected = '';
      if (rawMembers.any((m) => m['user_id'].toString() == currentUserId)) {
        selected = currentUserId!;
      } else if (rawMembers.isNotEmpty) {
        selected = rawMembers.first['user_id'].toString();
      }

      if (!mounted) return;
      setState(() {
        _items = rawItems;
        _members = rawMembers;
        _payerId = payer;
        _selectedUserId = selected;
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

  void _toggleSingleItem(Map<String, dynamic> item) {
    if (_selectedUserId.isEmpty) return;
    final itemId = item['id'].toString();
    final currentMap = _draftAllocations[itemId] ?? {};
    final currentQty = currentMap[_selectedUserId] ?? 0;

    setState(() {
      _error = null;
      if (currentQty > 0) {
        currentMap[_selectedUserId] = 0;
      } else {
        currentMap[_selectedUserId] = 1;
      }
      _draftAllocations[itemId] = Map.from(currentMap);
    });
  }

  void _openSplitModal(Map<String, dynamic> item) {
    final itemId = item['id'].toString();
    final currentMap = _draftAllocations[itemId] ?? {};
    setState(() {
      _splitItem = item;
      _itemModalAllocations = Map<String, int>.from(currentMap);
    });
    _showSplitBottomSheet();
  }

  void _showSplitBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (_splitItem == null) return const SizedBox.shrink();
            final itemName = _splitItem!['name']?.toString() ?? 'Item';
            final totalQuantity = (_splitItem!['quantity'] as num?)?.toInt() ?? 1;

            final member = _members.firstWhere(
              (m) => m['user_id'].toString() == _selectedUserId,
              orElse: () => _members.isNotEmpty ? _members.first : {'user': {'display_name': 'Member'}},
            );
            final user = member['user'] as Map<String, dynamic>? ?? {};
            final memberName = getShortName(user['display_name'] as String?, user['email'] as String?);

            final currentVal = _itemModalAllocations[_selectedUserId] ?? 0;
            final totalAllocated = _itemModalAllocations.values.fold(0, (sum, val) => sum + val);
            final remaining = max(0, totalQuantity - totalAllocated);

            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How many did $memberName have?',
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$itemName · $totalQuantity units total',
                              style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textGray),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: user['display_name'] as String?,
                          email: user['email'] as String?,
                          avatarUrl: user['avatar_url'] as String?,
                          size: AvatarSize.small,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            memberName,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Text('units', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                        const SizedBox(width: 12),
                        // Minus button
                        InkWell(
                          onTap: currentVal > 0
                              ? () {
                                  setModalState(() {
                                    _itemModalAllocations[_selectedUserId] = currentVal - 1;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: currentVal > 0 ? AppColors.dimBlue : AppColors.inputFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: currentVal > 0 ? AppColors.primaryBlue : AppColors.textGray,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$currentVal',
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Plus button
                        InkWell(
                          onTap: totalAllocated < totalQuantity
                              ? () {
                                  setModalState(() {
                                    _itemModalAllocations[_selectedUserId] = currentVal + 1;
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: totalAllocated < totalQuantity ? AppColors.dimBlue : AppColors.inputFill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: totalAllocated < totalQuantity ? AppColors.primaryBlue : AppColors.textGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap Done and select another member to split any remaining units.',
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  // Remaining status badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: remaining == 0
                          ? AppColors.successGreen.withValues(alpha: 0.1)
                          : Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      remaining == 0
                          ? 'All units assigned'
                          : '$remaining unit${remaining == 1 ? '' : 's'} left to assign',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: remaining == 0 ? AppColors.successGreen : Colors.amber.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          final itemId = _splitItem!['id'].toString();
                          _draftAllocations[itemId] = Map<String, int>.from(_itemModalAllocations);
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _assignAllToOwner() {
    if (_members.length != 1) return;
    final ownerId = _members.first['user_id'].toString();

    setState(() {
      for (final item in _items) {
        final itemId = item['id'].toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        _draftAllocations[itemId] = {ownerId: qty};
      }
    });
  }

  void _showPayerPicker() {
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
            const Text(
              'Who paid the bill?',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._members.map((m) {
              final uid = m['user_id'].toString();
              final isPayer = uid == _payerId;
              final user = m['user'] as Map<String, dynamic>? ?? {};
              final name = getShortName(user['display_name'] as String?, user['email'] as String?);

              return ListTile(
                leading: UserAvatar(
                  name: user['display_name'] as String?,
                  email: user['email'] as String?,
                  avatarUrl: user['avatar_url'] as String?,
                  size: AvatarSize.small,
                ),
                title: Text(name, style: TextStyle(fontWeight: isPayer ? FontWeight.bold : FontWeight.normal)),
                trailing: isPayer ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(billServiceProvider).setPayer(billId: widget.billId, payerId: uid);
                    setState(() => _payerId = uid);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update payer: $e')),
                      );
                    }
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddPersonSheet() {
    _personNameController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                      'Add Person',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textGray),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add someone locally without sending an invite.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Person Name (optional)',
                  style: TextStyle(color: AppColors.textGray, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: TextField(
                    controller: _personNameController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText: 'e.g. Alice',
                      hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Leave blank to create the next profile automatically, such as A, B, or C.',
                  style: TextStyle(color: AppColors.textGray, fontSize: 11),
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
                        onPressed: _addingPerson
                            ? null
                            : () async {
                                setSheetState(() => _addingPerson = true);
                                try {
                                  final name = _personNameController.text.trim();
                                  final result = await ref.read(billServiceProvider).addMember(widget.billId, name.isNotEmpty ? name : null);
                                  final newMember = result['member'] as Map<String, dynamic>;
                                  final newUid = newMember['user_id'].toString();

                                  // Initialize allocations
                                  for (final entry in _draftAllocations.entries) {
                                    entry.value.putIfAbsent(newUid, () => 0);
                                  }

                                  setState(() {
                                    _members.add(newMember);
                                    _selectedUserId = newUid;
                                  });

                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed to add person: $e')),
                                    );
                                  }
                                } finally {
                                  setSheetState(() => _addingPerson = false);
                                }
                              },
                        child: _addingPerson
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Add person', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _proceedToSummary() async {
    if (_savingBill) return;

    // Check if every item has all its units allocated
    for (final item in _items) {
      final itemId = item['id'].toString();
      final itemName = item['name']?.toString() ?? 'Item';
      final requiredQty = (item['quantity'] as num?)?.toInt() ?? 1;
      final allocations = _draftAllocations[itemId] ?? {};
      final allocatedSum = allocations.values.fold(0, (sum, val) => sum + val);

      if (allocatedSum < requiredQty) {
        setState(() {
          _error = 'Assign all $requiredQty units of "$itemName" before continuing.';
        });
        return;
      }
    }

    setState(() {
      _savingBill = true;
      _error = null;
    });

    try {
      final billService = ref.read(billServiceProvider);

      // Save assignments for all items
      for (final item in _items) {
        final itemId = item['id'].toString();
        final allocMap = _draftAllocations[itemId] ?? {};
        final assignments = <Map<String, dynamic>>[];

        allocMap.forEach((userId, qty) {
          if (qty > 0) {
            assignments.add({'user_id': userId, 'quantity': qty});
          }
        });

        await billService.setItemAssignments(
          billId: widget.billId,
          itemId: itemId,
          assignments: assignments,
        );
      }

      if (!mounted) return;
      context.go('/bill/${widget.billId}/summary');
    } catch (e) {
      if (mounted) {
        setState(() {
          _savingBill = false;
          _error = 'Could not save assignments: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: ScreenAppBar(title: 'Assign'),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    final payerMember = _members.firstWhere(
      (m) => m['user_id'].toString() == _payerId,
      orElse: () => _members.isNotEmpty ? _members.first : {'user': {'display_name': 'Unknown'}},
    );
    final payerUser = payerMember['user'] as Map<String, dynamic>? ?? {};
    final payerName = getShortName(payerUser['display_name'] as String?, payerUser['email'] as String?);

    final selectedMember = _members.firstWhere(
      (m) => m['user_id'].toString() == _selectedUserId,
      orElse: () => _members.isNotEmpty ? _members.first : {'user': {'display_name': 'Member'}},
    );
    final selectedUser = selectedMember['user'] as Map<String, dynamic>? ?? {};
    final selectedName = getShortName(selectedUser['display_name'] as String?, selectedUser['email'] as String?);

    final totalAmount = _items.fold<double>(
      0.0,
      (sum, item) => sum + (((item['quantity'] as num?)?.toInt() ?? 1) * ((item['unit_price'] as num?)?.toDouble() ?? 0.0)),
    );

    final unassignedCount = _items.where((item) {
      final itemId = item['id'].toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final allocMap = _draftAllocations[itemId] ?? {};
      final sum = allocMap.values.fold(0, (s, val) => s + val);
      return sum < qty;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: ScreenAppBar(
        title: 'Assign',
        backHref: '/bill/${widget.billId}/items',
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payer Card
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showPayerPicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.inputBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                            ),
                          ],
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
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Paid by', style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    payerName,
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textGray, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Member Selection Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign to',
                          style: TextStyle(color: AppColors.textGray, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._members.map((m) {
                                final uid = m['user_id'].toString();
                                final isSelected = uid == _selectedUserId;
                                final user = m['user'] as Map<String, dynamic>? ?? {};
                                final name = getShortName(user['display_name'] as String?, user['email'] as String?);

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedUserId = uid),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Column(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(2.5),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                                                  width: 2.5,
                                                ),
                                              ),
                                              child: UserAvatar(
                                                name: user['display_name'] as String?,
                                                email: user['email'] as String?,
                                                avatarUrl: user['avatar_url'] as String?,
                                                size: AvatarSize.normal,
                                              ),
                                            ),
                                            if (uid == _payerId)
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.amber,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.star, color: Colors.white, size: 10),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: 54,
                                          child: Text(
                                            name,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              // Add Person button
                              GestureDetector(
                                onTap: _showAddPersonSheet,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.primaryBlue, width: 1.5),
                                          color: AppColors.dimBlue.withValues(alpha: 0.5),
                                        ),
                                        child: const Icon(Icons.add, color: AppColors.primaryBlue, size: 22),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Add person',
                                        style: TextStyle(
                                          color: AppColors.primaryBlue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap items below to assign them to $selectedName.',
                          style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Solo owner helper
                  if (_members.length == 1 && unassignedCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.dimBlue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            name: selectedUser['display_name'] as String?,
                            email: selectedUser['email'] as String?,
                            avatarUrl: selectedUser['avatar_url'] as String?,
                            size: AvatarSize.small,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Calculating for $selectedName? Assign all items to yourself.',
                              style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppColors.primaryBlue),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _assignAllToOwner,
                            child: const Text('Assign all', style: TextStyle(color: AppColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Items Card
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
                                  'Who had what?',
                                  style: TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '฿${totalAmount.toStringAsFixed(2)} across ${_items.length} items',
                                  style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/bill/${widget.billId}/invite'),
                              icon: const Icon(Icons.link, size: 16),
                              label: const Text('Invite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryBlue,
                                side: const BorderSide(color: AppColors.primaryBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._items.map((item) {
                          final itemId = item['id'].toString();
                          final itemName = item['name']?.toString() ?? 'Item';
                          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                          final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;

                          final allocMap = _draftAllocations[itemId] ?? {};
                          final isAssignedToSelected = (allocMap[_selectedUserId] ?? 0) > 0;

                          // Stacked assigned users
                          final assignedUsers = _members
                              .where((m) => (allocMap[m['user_id'].toString()] ?? 0) > 0)
                              .map((m) {
                                final u = m['user'] as Map<String, dynamic>? ?? {};
                                return AvatarStackItem(
                                  name: u['display_name'] as String?,
                                  email: u['email'] as String?,
                                  avatarUrl: u['avatar_url'] as String?,
                                );
                              })
                              .toList();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (quantity == 1) {
                                    _toggleSingleItem(item);
                                  } else {
                                    _openSplitModal(item);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isAssignedToSelected
                                        ? const Color(0xFFE8FDF0)
                                        : AppColors.cardWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isAssignedToSelected
                                          ? AppColors.selectedGreen.withValues(alpha: 0.6)
                                          : AppColors.inputBorder,
                                      width: isAssignedToSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemName,
                                              style: TextStyle(
                                                color: isAssignedToSelected ? AppColors.selectedGreen : AppColors.textDark,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'x$quantity · ฿${unitPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AvatarStack(users: assignedUsers),
                                      if (quantity > 1) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right, color: AppColors.textGray, size: 20),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Fixed Bottom Bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/bill/${widget.billId}/invite'),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _savingBill ? null : _proceedToSummary,
                    child: _savingBill
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Proceed to Summary',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
