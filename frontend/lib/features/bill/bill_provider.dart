import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bill_service.dart';

// ── Bill model ────────────────────────────────────────────────────────────────

class Bill {
  final String id;
  final String name;
  final DateTime date;
  final String createdBy;
  final String? paidBy;
  final String status;
  final String inviteCode;
  final DateTime createdAt;
  final double? serviceChargePercent;
  final double? vatPercent;
  final String? receiptImageUrl;
  final int memberCount;
  final String? ownerPromptpay;

  const Bill({
    required this.id,
    required this.name,
    required this.date,
    required this.createdBy,
    this.paidBy,
    required this.status,
    required this.inviteCode,
    required this.createdAt,
    this.serviceChargePercent,
    this.vatPercent,
    this.receiptImageUrl,
    this.memberCount = 0,
    this.ownerPromptpay,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: (json['id'] ?? json['Id'] ?? '').toString(),
    name: (json['name'] ?? json['Name'] ?? '').toString(),
    date: DateTime.tryParse((json['date'] ?? json['Date'] ?? '').toString()) ?? DateTime.now(),
    createdBy: (json['created_by'] ?? json['createdBy'] ?? json['CreatedBy'] ?? '').toString(),
    paidBy: _parseString(json['paid_by'] ?? json['paidBy']),
    status: (json['status'] ?? json['Status'] ?? 'active').toString(),
    inviteCode: (json['invite_code'] ?? json['inviteCode'] ?? json['InviteCode'] ?? '').toString(),
    createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'] ?? json['CreatedAt'] ?? '').toString()) ?? DateTime.now(),
    serviceChargePercent: _toDouble(json['service_charge_pct'] ?? json['serviceChargePct'] ?? json['ServiceChargePct']),
    vatPercent: _toDouble(json['vat_pct'] ?? json['vatPct'] ?? json['VatPct']),
    receiptImageUrl: (json['receipt_image_url'] ?? json['receiptImageUrl'] ?? json['ReceiptImageUrl'])?.toString(),
    memberCount: (json['member_count'] ?? json['memberCount'] ?? json['MemberCount'] ?? 0) as int,
    ownerPromptpay: (json['owner_promptpay'] ?? json['ownerPromptpay'] ?? json['OwnerPromptpay'])?.toString(),
  );

  Bill copyWith({String? paidBy}) => Bill(
    id: id,
    name: name,
    date: date,
    createdBy: createdBy,
    paidBy: paidBy ?? this.paidBy,
    status: status,
    inviteCode: inviteCode,
    createdAt: createdAt,
    serviceChargePercent: serviceChargePercent,
    vatPercent: vatPercent,
    receiptImageUrl: receiptImageUrl,
    memberCount: memberCount,
    ownerPromptpay: ownerPromptpay,
  );
}

// ── BillItem model ────────────────────────────────────────────────────────────

class BillItem {
  final String id;
  final String billId;
  final String name;
  final int quantity;
  final double unitPrice;
  final bool isPending;
  final List<String>? assignedTo;

  const BillItem({
    required this.id,
    required this.billId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.isPending = false,
    this.assignedTo,
  });

  double get lineTotal => unitPrice * quantity;

  factory BillItem.fromJson(Map<String, dynamic> json) {
    // item_assigns comes from backend as array of {user_id: string} objects
    final assigns = (json['item_assigns'] as List<dynamic>?) ?? [];
    final assignedTo = assigns.map((a) => (a['user_id'] ?? a['userId'] ?? '') as String).toList();
    return BillItem(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      billId: (json['bill_id'] ?? json['billId'] ?? json['BillId'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      quantity: (json['quantity'] ?? json['Quantity'] ?? 1) as int,
      unitPrice: _toDouble(json['unit_price'] ?? json['unitPrice'] ?? json['UnitPrice']) ?? 0.0,
      assignedTo: assignedTo,
    );
  }

  BillItem copyWith({
    String? id,
    String? name,
    int? quantity,
    double? unitPrice,
    bool? isPending,
    List<String>? assignedTo,
  }) => BillItem(
    id: id ?? this.id,
    billId: billId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    isPending: isPending ?? this.isPending,
    assignedTo: assignedTo ?? this.assignedTo,
  );
}

// ── helpers ───────────────────────────────────────────────────────────────────

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty || s == 'null' || s == 'NULL' || s == 'Null') return null;
  return s;
}

String _tempId() => 'temp_${DateTime.now().microsecondsSinceEpoch}';

// ── BillListNotifier ──────────────────────────────────────────────────────────

class BillListNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() async {
    final data = await ref.read(billServiceProvider).listBills();
    return data.map(Bill.fromJson).toList();
  }

  Future<void> refreshBills() async {
    state = state.whenData((data) => data); // preserve current data while loading
    final fresh = await AsyncValue.guard(() async {
      final data = await ref.read(billServiceProvider).listBills();
      return data.map(Bill.fromJson).toList();
    });
    state = fresh;
  }
}

final billListProvider = AsyncNotifierProvider<BillListNotifier, List<Bill>>(
  BillListNotifier.new,
);

// ── BillNotifier (single bill creation) ──────────────────────────────────────

class BillNotifier extends AsyncNotifier<Bill?> {
  @override
  Future<Bill?> build() async => null;

  Future<void> createBill({
    required String name,
    required DateTime date,
    required double vatPercent,
    double? serviceChargePercent,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(billServiceProvider).createBill(
            name: name,
            date: date,
            vatPercent: vatPercent,
            serviceChargePercent: serviceChargePercent,
          );
      return Bill.fromJson(data['bill'] as Map<String, dynamic>);
    });
  }
}

final billProvider = AsyncNotifierProvider<BillNotifier, Bill?>(
  BillNotifier.new,
);

// ── BillItemsNotifier (per-bill item list with optimistic updates) ─────────────

class BillItemsNotifier extends AsyncNotifier<List<BillItem>> {
  BillItemsNotifier(this.billId);
  final String billId;

  @override
  Future<List<BillItem>> build() async {
    final data = await ref.read(billServiceProvider).getBill(billId);
    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    return rawItems
        .cast<Map<String, dynamic>>()
        .map(BillItem.fromJson)
        .toList();
  }

  Future<void> addItem({
    required String name,
    required int quantity,
    required double unitPrice,
  }) async {
    final tempId = _tempId();
    final tempItem = BillItem(
      id: tempId,
      billId: billId,
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      isPending: true,
    );

    // optimistic insert
    final current = state.value ?? [];
    state = AsyncData([...current, tempItem]);

    try {
      final json = await ref.read(billServiceProvider).addItem(
            billId: billId,
            name: name,
            quantity: quantity,
            unitPrice: unitPrice,
          );
      final confirmed = BillItem.fromJson(json);
      final updated = (state.value ?? [])
          .map((i) => i.id == tempId ? confirmed : i)
          .toList();
      state = AsyncData(updated);
    } catch (_) {
      // rollback
      state = AsyncData(
        (state.value ?? []).where((i) => i.id != tempId).toList(),
      );
      rethrow;
    }
  }

  Future<void> addItemsBulk(List<Map<String, dynamic>> items) async {
    final tempIds = List.generate(items.length, (_) => _tempId());
    final tempItems = List.generate(
      items.length,
      (i) => BillItem(
        id: tempIds[i],
        billId: billId,
        name: items[i]['name'] as String,
        quantity: items[i]['quantity'] as int,
        unitPrice: (items[i]['unit_price'] as num).toDouble(),
        isPending: true,
      ),
    );

    final current = state.value ?? [];
    state = AsyncData([...current, ...tempItems]);

    try {
      final confirmed = await ref.read(billServiceProvider).addItemsBulk(
            billId: billId,
            items: items,
          );
      final confirmedItems = confirmed.map(BillItem.fromJson).toList();
      final updated = List<BillItem>.from(state.value ?? []);
      for (var i = 0; i < tempIds.length && i < confirmedItems.length; i++) {
        final idx = updated.indexWhere((item) => item.id == tempIds[i]);
        if (idx >= 0) updated[idx] = confirmedItems[i];
      }
      state = AsyncData(updated);
    } catch (_) {
      state = AsyncData(
        (state.value ?? [])
            .where((i) => !tempIds.contains(i.id))
            .toList(),
      );
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    final before = List<BillItem>.from(state.value ?? []);

    // optimistic remove
    state = AsyncData(before.where((i) => i.id != itemId).toList());

    try {
      await ref
          .read(billServiceProvider)
          .deleteItem(billId: billId, itemId: itemId);
    } catch (_) {
      // rollback
      state = AsyncData(before);
      rethrow;
    }
  }
}

final billItemsProvider = AsyncNotifierProvider.family.autoDispose<
    BillItemsNotifier, List<BillItem>, String>(
  (billId) => BillItemsNotifier(billId),
);
