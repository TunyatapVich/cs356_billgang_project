import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bill/bill_provider.dart';
import '../bill/bill_service.dart';
import '../../core/socket/socket_client.dart';

// ── Member model for assign screen ────────────────────────────────────────────

class AssignMember {
  final String id;
  final String name;
  final String avatar;
  const AssignMember({required this.id, required this.name, required this.avatar});
}

// ── Assign state ──────────────────────────────────────────────────────────────

class AssignState {
  final List<BillItem> items; // current local state (may have unsaved changes)
  final List<BillItem> originalItems; // last saved state from server
  final List<AssignMember> members;
  final int selectedMemberIndex;
  final String? payerId;
  final bool loading;
  final bool saving; // true while saveAssignments is running
  final Object? error;

  const AssignState({
    this.items = const [],
    this.originalItems = const [],
    this.members = const [],
    this.selectedMemberIndex = 0,
    this.payerId,
    this.loading = true,
    this.saving = false,
    this.error,
  });

  AssignState copyWith({
    List<BillItem>? items,
    List<BillItem>? originalItems,
    List<AssignMember>? members,
    int? selectedMemberIndex,
    String? payerId,
    bool? loading,
    bool? saving,
    Object? error,
  }) {
    return AssignState(
      items: items ?? this.items,
      originalItems: originalItems ?? this.originalItems,
      members: members ?? this.members,
      selectedMemberIndex: selectedMemberIndex ?? this.selectedMemberIndex,
      payerId: payerId ?? this.payerId,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: error,
    );
  }

  String? get selectedMemberId =>
      members.isNotEmpty ? members[selectedMemberIndex].id : null;
}

// ── AssignNotifier ────────────────────────────────────────────────────────────

class AssignNotifier extends Notifier<AssignState> {
  SocketClient? _socket;
  StreamSubscription? _socketSub;

  @override
  AssignState build() {
    ref.onDispose(() {
      _socketSub?.cancel();
      _socket?.disconnect();
    });
    return const AssignState();
  }

  BillService get _billService => ref.read(billServiceProvider);

  Future<void> loadBill(String billId) async {
    state = state.copyWith(loading: true, error: null);

    try {
      final data = await _billService.getBill(billId);
      final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
      final items = itemsRaw
          .cast<Map<String, dynamic>>()
          .map((itemJson) => BillItem.fromJson(itemJson))
          .toList();

      final membersRaw = (data['members'] as List<dynamic>?) ?? [];
      final members = membersRaw.cast<Map<String, dynamic>>().map((m) {
        final user = m['user'] as Map<String, dynamic>? ?? {};
        final displayName =
            (user['display_name'] ?? user['email'] ?? 'U') as String;
        final initials =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
        return AssignMember(
          id: (m['user_id'] ?? user['id'] ?? '').toString(),
          name: displayName,
          avatar: initials,
        );
      }).toList();

      // paid_by comes from the serialized bill
      final billData = data['bill'] as Map<String, dynamic>?;
      final payerId = (billData?['paid_by'] ?? data['paid_by'])?.toString();

      state = state.copyWith(
        items: items,
        originalItems: items,
        members: members,
        payerId: payerId,
        selectedMemberIndex: 0,
        loading: false,
      );

      _connectSocket(billId);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  void selectMember(int index) {
    if (index >= 0 && index < state.members.length) {
      state = state.copyWith(selectedMemberIndex: index);
    }
  }

  /// Toggles item selection locally (no API call). Returns true if toggled.
  bool toggleItem(int itemIndex) {
    final memberId = state.selectedMemberId;
    if (memberId == null) return false;

    final item = state.items[itemIndex];
    final assigned = List<String>.from(item.assignedTo ?? []);
    final isCurrentlyAssigned = assigned.contains(memberId);

    state = state.copyWith(
      items: [
        for (var i = 0; i < state.items.length; i++)
          if (i == itemIndex)
            item.copyWith(
              assignedTo: isCurrentlyAssigned
                  ? assigned.where((id) => id != memberId).toList()
                  : [...assigned, memberId],
            )
          else
            state.items[i],
      ],
    );
    return true;
  }

  bool isItemSelected(BillItem item) =>
      item.assignedTo?.contains(state.selectedMemberId) ?? false;

  /// Diffs current items against originalItems and syncs only changed assignments.
  Future<void> saveAssignments(String billId) async {
    state = state.copyWith(saving: true, error: null);

    try {
      for (var i = 0; i < state.items.length; i++) {
        final current = state.items[i];
        final original = state.originalItems.length > i ? state.originalItems[i] : null;
        if (original == null) continue;

        final currentSet = Set<String>.from(current.assignedTo ?? []);
        final originalSet = Set<String>.from(original.assignedTo ?? []);

        if (currentSet.difference(originalSet).isNotEmpty) {
          for (final userId in currentSet.difference(originalSet)) {
            await _billService.assignItem(billId: billId, itemId: current.id, userId: userId);
          }
        }
        if (originalSet.difference(currentSet).isNotEmpty) {
          for (final userId in originalSet.difference(currentSet)) {
            await _billService.unassignItem(billId: billId, itemId: current.id, userId: userId);
          }
        }
      }

      state = state.copyWith(saving: false, originalItems: List.from(state.items));
    } catch (e) {
      state = state.copyWith(saving: false, error: e);
    }
  }

  void setPayer(String billId, String payerId) async {
    state = state.copyWith(payerId: payerId);
    try {
      await _billService.setPayer(billId: billId, payerId: payerId);
    } catch (_) {
      // WebSocket will update us on success; on failure just revert
    }
  }

  void _connectSocket(String billId) {
    _socketSub?.cancel();
    _socket?.disconnect();

    _socket = SocketClient();
    _socket!.connect(billId, ''); // token handled server-side via cookie
    _socket!.stream.listen(_handleSocketEvent);
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final itemId = event['item_id'] as String?;
    final userId = event['user_id'] as String?;

    if (itemId == null || userId == null) return;

    switch (type) {
      case 'item_assigned':
        _applyAssign(itemId, userId);
        break;
      case 'item_unassigned':
        _applyUnassign(itemId, userId);
        break;
      case 'item_added':
        // Refetch bill to get new item with full data
        // For now, ignore - new items will appear on next load
        break;
      case 'item_removed':
        state = state.copyWith(
          items: state.items.where((i) => i.id != itemId).toList(),
        );
        break;
      case 'payer_set':
        final payerId = event['paid_by'] as String?;
        if (payerId != null) {
          state = state.copyWith(payerId: payerId);
        }
        break;
    }
  }

  void _applyAssign(String itemId, String userId) {
    final item = state.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    if (item.assignedTo?.contains(userId) ?? false) return; // already present, no-op
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id == itemId)
            i.copyWith(assignedTo: [...(i.assignedTo ?? []), userId])
          else
            i,
      ],
    );
  }

  void _applyUnassign(String itemId, String userId) {
    final item = state.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    if (!(item.assignedTo?.contains(userId) ?? false)) return; // already absent, no-op
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id == itemId)
            i.copyWith(assignedTo: i.assignedTo!.where((id) => id != userId).toList())
          else
            i,
      ],
    );
  }
}

final assignProvider =
    NotifierProvider.autoDispose<AssignNotifier, AssignState>(
  AssignNotifier.new,
);
