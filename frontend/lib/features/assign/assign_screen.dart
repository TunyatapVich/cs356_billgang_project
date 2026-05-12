import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../bill/bill_provider.dart';
import '../bill/bill_service.dart';

class AssignScreen extends ConsumerStatefulWidget {
  const AssignScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends ConsumerState<AssignScreen> {
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputBorder = Color(0xFFDCDFEA);
  static const selectedColor = Color(0xFF34C759);
  static const dimColor = Color(0xFFE4E6FF);

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final billData = await ref.read(billServiceProvider).getBill(widget.billId);
      final itemsRaw = (billData['items'] as List<dynamic>?) ?? [];
      _items = itemsRaw.cast<Map<String, dynamic>>().map(BillItem.fromJson).toList();

      // TODO: replace with real members from API when ready
      _members = [
        _Member(id: '1', name: 'You', avatar: 'Y'),
        _Member(id: '2', name: 'Friend A', avatar: 'A'),
        _Member(id: '3', name: 'Friend B', avatar: 'B'),
      ];

      if (!mounted) return;
      setState(() {
        _loading = false;
        _selectedMemberIndex = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toggleItem(int itemIndex) {
    final memberId = _members[_selectedMemberIndex].id;
    setState(() {
      final item = _items[itemIndex];
      final assigned = item.assignedTo ?? [];
      if (assigned.contains(memberId)) {
        _items[itemIndex] = item.copyWith(
          assignedTo: assigned.where((id) => id != memberId).toList(),
        );
      } else {
        _items[itemIndex] = item.copyWith(assignedTo: [...assigned, memberId]);
      }
    });
  }

  bool _isSelected(BillItem item) =>
      item.assignedTo?.contains(_members[_selectedMemberIndex].id) ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => context.go('/bill/${widget.billId}/summary'),
        ),
        title: const Text(
          'Assign',
          style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/bill/${widget.billId}/summary'),
            child: const Text(
              'Done',
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildMemberBar(),
                    Expanded(child: _buildItemList()),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 42),
          const SizedBox(height: 12),
          Text(_error.toString(), style: const TextStyle(color: textGray)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
            onPressed: _loadData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: cardWhite,
        border: Border(bottom: BorderSide(color: inputBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: sel ? dimColor : const Color(0xFFF2F4FC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? primaryBlue : inputBorder,
                          width: sel ? 2.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          m.avatar,
                          style: TextStyle(
                            color: sel ? primaryBlue : textGray,
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
                        color: sel ? primaryBlue : textGray,
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

  Widget _buildItemList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, color: textGray.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 12),
            const Text('No items yet', style: TextStyle(color: textGray)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final sel = _isSelected(item);
        return GestureDetector(
          onTap: () => _toggleItem(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFE8FDF0) : cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? selectedColor.withValues(alpha: 0.4) : inputBorder,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: sel ? selectedColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? selectedColor : textGray.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: sel ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: sel ? selectedColor : textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'x${item.quantity}  ·  ฿${item.unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(color: textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '฿${item.lineTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: sel ? selectedColor : primaryBlue,
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

class _Member {
  final String id;
  final String name;
  final String avatar;
  const _Member({required this.id, required this.name, required this.avatar});
}
