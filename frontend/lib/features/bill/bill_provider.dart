import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bill_service.dart';

// Bill model — matches the shape your backend returns from POST /bills/create.
class Bill {
  final String id;
  final String name;
  final DateTime date;
  final String createdBy;
  final String status;
  final String inviteCode;
  final DateTime createdAt;
  final double? serviceChargePercent;
  final double? vatPercent;
  final String? receiptImageUrl;
  final int memberCount;

  const Bill({
    required this.id,
    required this.name,
    required this.date,
    required this.createdBy,
    required this.status,
    required this.inviteCode,
    required this.createdAt,
    this.serviceChargePercent,
    this.vatPercent,
    this.receiptImageUrl,
    this.memberCount = 0,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'] as String,
    name: json['name'] as String,
    date: DateTime.parse(json['date'] as String),
    createdBy: json['created_by'] as String,
    status: json['status'] as String,
    inviteCode: json['invite_code'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    serviceChargePercent: _toDouble(json['service_charge_pct']),
    vatPercent: _toDouble(json['vat_pct']),
    receiptImageUrl: json['receipt_image_url'] as String?,
    memberCount: json['member_count'] as int? ?? 0,
  );
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// BillListNotifier — loads all bills that belong to the current user.
class BillListNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() async {
    final data = await ref.read(billServiceProvider).listBills();
    return data.map(Bill.fromJson).toList();
  }

  Future<void> refreshBills() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(billServiceProvider).listBills();
      return data.map(Bill.fromJson).toList();
    });
  }
}

// BillNotifier — manages bill state and calls BillService for HTTP requests.
// AsyncNotifier<Bill?> means state is one of: loading | error | Bill | null.
class BillNotifier extends AsyncNotifier<Bill?> {
  @override
  Future<Bill?> build() async {
    return null;
  }

  Future<void> createBill({
    required String name,
    required DateTime date,
    required double vatPercent,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = await ref
          .read(billServiceProvider)
          .createBill(name: name, date: date, vatPercent: vatPercent);

      return Bill.fromJson(data['bill'] as Map<String, dynamic>);
    });
  }

  Future<void> deleteBill(String billId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(billServiceProvider).deleteBill(billId);
      return null;
    });
  }
}

// The provider — exposes BillNotifier to any widget via ref.watch / ref.read.
final billProvider = AsyncNotifierProvider<BillNotifier, Bill?>(
  BillNotifier.new,
);

final billListProvider = AsyncNotifierProvider<BillListNotifier, List<Bill>>(
  BillListNotifier.new,
);
