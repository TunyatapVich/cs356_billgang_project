import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../bill/bill_provider.dart';
import '../bill/bill_service.dart';
import '../../core/socket/socket_client.dart';
import '../../core/storage/token_storage.dart';

// ── Member model for assign screen ────────────────────────────────────────────

class AssignMember {
  final String id;
  final String name;
  final String avatar;
  const AssignMember({required this.id, required this.name, required this.avatar});
}

// ── Assign state ──────────────────────────────────────────────────────────────

class AssignState {
  final List<BillItem> items;
  final List<AssignMember> members;
  final int selectedMemberIndex;
  final String? payerId;
  final bool loading;
  final Object? error;

  const AssignState({
    this.items = const [],
    this.members = const [],
    this.selectedMemberIndex = 0,
    this.payerId,
    this.loading = true,
    this.error,
  });

  AssignState copyWith({
    List<BillItem>? items,
    List<AssignMember>? members,
    int? selectedMemberIndex,
    String? payerId,
    bool? loading,
    Object? error,
  }) {
    return AssignState(
      items: items ?? this.items,
      members: members ?? this.members,
      selectedMemberIndex: selectedMemberIndex ?? this.selectedMemberIndex,
      payerId: payerId ?? this.payerId,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  String? get selectedMemberId =>
      selectedMemberIndex >= 0 && selectedMemberIndex < members.length
          ? members[selectedMemberIndex].id
          : null;
}

// ── AssignNotifier ────────────────────────────────────────────────────────────

class AssignNotifier extends Notifier<AssignState> {
  SocketClient? _socket;
  StreamSubscription? _socketSub;
  String? _billId;

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
    _billId = billId;
    state = state.copyWith(loading: true, error: null);

    try {
      final data = await _billService.getBill(billId);
      final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
      final items = itemsRaw
          .cast<Map<String, dynamic>>()
          .map((itemJson) => BillItem.fromJson(itemJson))
          .toList();

      final membersRaw = (data['members'] as List<dynamic>?) ?? [];
      var members = membersRaw.cast<Map<String, dynamic>>().map((m) {
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
      }).where((m) => m.id.isNotEmpty).toList();

      // Fallback: API should always include the current user as a member,
      // but if parsing fails or the list is empty, synthesise an entry so
      // the user can still assign items to themselves.
      if (members.isEmpty) {
        final currentUser = ref.read(authProvider).value;
        if (currentUser != null) {
          final name = currentUser.displayName ?? currentUser.email;
          final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          members = [AssignMember(id: currentUser.id, name: name, avatar: avatar)];
        }
      } else {
        // Ensure the current user is present in the members list; if not,
        // append them so they can still assign items to themselves.
        final currentUser = ref.read(authProvider).value;
        if (currentUser != null &&
            !members.any((m) => m.id == currentUser.id)) {
          final name = currentUser.displayName ?? currentUser.email;
          final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'U';
          members.add(AssignMember(id: currentUser.id, name: name, avatar: avatar));
        }
      }

      // paid_by comes from the serialized bill; fall back to created_by for new bills
      final billData = data['bill'] as Map<String, dynamic>?;
      final payerId = (billData?['paid_by'] ?? billData?['created_by'])?.toString();

      // Pre-select the current user if they are in the members list,
      // otherwise default to index 0.
      final currentUser = ref.read(authProvider).value;
      int selectedIdx = 0;
      if (currentUser != null) {
        final idx = members.indexWhere((m) => m.id == currentUser.id);
        if (idx >= 0) selectedIdx = idx;
      }

      state = state.copyWith(
        items: items,
        members: members,
        payerId: payerId,
        selectedMemberIndex: selectedIdx,
        loading: false,
      );

      _connectSocket(billId);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  void selectMember(int index) {
    if (state.members.isEmpty) return;
    final validIndex = index.clamp(-1, state.members.length - 1);
    state = state.copyWith(selectedMemberIndex: validIndex);
  }

  /// Returns false if no member is selected; throws on API failure.
  Future<bool> toggleItem(String billId, int itemIndex) async {
    final memberId = state.selectedMemberId;
    if (memberId == null) return false;

    final item = state.items[itemIndex];
    final assigned = List<String>.from(item.assignedTo ?? []);
    final isCurrentlyAssigned = assigned.contains(memberId);

    // Optimistic update
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

    try {
      if (isCurrentlyAssigned) {
        await _billService.unassignItem(
          billId: billId,
          itemId: item.id,
          userId: memberId,
        );
      } else {
        await _billService.assignItem(
          billId: billId,
          itemId: item.id,
          userId: memberId,
        );
      }
      return true;
    } catch (e) {
      // Revert optimistic update then surface the real error
      state = state.copyWith(
        items: [
          for (var i = 0; i < state.items.length; i++)
            if (i == itemIndex) item else state.items[i],
        ],
      );
      rethrow;
    }
  }

  bool isItemSelected(BillItem item) =>
      item.assignedTo?.contains(state.selectedMemberId) ?? false;

  Future<void> setPayer(String billId, String payerId) async {
    if (payerId == state.payerId) return;
    final previous = state.payerId;
    state = state.copyWith(payerId: payerId);
    try {
      await _billService.setPayer(billId: billId, payerId: payerId);
    } catch (e) {
      state = state.copyWith(payerId: previous);
      rethrow;
    }
  }

  Future<void> _connectSocket(String billId) async {
    _socketSub?.cancel();
    _socket?.disconnect();

    final token = await TokenStorage.read() ?? '';
    _socket = SocketClient();
    _socket!.connect(billId, token);
    _socketSub = _socket!.stream.listen(_handleSocketEvent);
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'item_assigned':
        final itemId = event['item_id'] as String?;
        final userId = event['user_id'] as String?;
        if (itemId != null && userId != null) _applyAssign(itemId, userId);
        break;
      case 'item_unassigned':
        final itemId = event['item_id'] as String?;
        final userId = event['user_id'] as String?;
        if (itemId != null && userId != null) _applyUnassign(itemId, userId);
        break;
      case 'item_removed':
        final itemId = event['item_id'] as String?;
        if (itemId != null) {
          state = state.copyWith(
            items: state.items.where((i) => i.id != itemId).toList(),
          );
        }
        break;
      case 'payer_set':
        final payerId = event['paid_by'] as String?;
        if (payerId != null && payerId != state.payerId) {
          state = state.copyWith(payerId: payerId);
        }
        break;
      case 'member_joined':
        if (_billId != null) loadBill(_billId!);
        ref.read(billListProvider.notifier).refreshBills();
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
