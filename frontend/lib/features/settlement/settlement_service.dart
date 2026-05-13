import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class DebtPerPerson {
  final String userId;
  final Map<String, dynamic> user;
  final double subtotal;
  final double owed;
  final double balance;

  const DebtPerPerson({
    required this.userId,
    required this.user,
    required this.subtotal,
    required this.owed,
    required this.balance,
  });

  factory DebtPerPerson.fromJson(Map<String, dynamic> json) => DebtPerPerson(
    userId: (json['user_id'] ?? '').toString(),
    user: (json['user'] as Map<String, dynamic>?) ?? {},
    subtotal: _toDouble(json['subtotal']) ?? 0,
    owed: _toDouble(json['owed']) ?? 0,
    balance: _toDouble(json['balance']) ?? 0,
  );
}

class DebtTransfer {
  final String fromUserId;
  final String toUserId;
  final Map<String, dynamic>? fromUser;
  final Map<String, dynamic>? toUser;
  final double amount;

  const DebtTransfer({
    required this.fromUserId,
    required this.toUserId,
    this.fromUser,
    this.toUser,
    required this.amount,
  });

  factory DebtTransfer.fromJson(Map<String, dynamic> json) => DebtTransfer(
    fromUserId: (json['from_user_id'] ?? '').toString(),
    toUserId: (json['to_user_id'] ?? '').toString(),
    fromUser: json['from_user'] as Map<String, dynamic>?,
    toUser: json['to_user'] as Map<String, dynamic>?,
    amount: _toDouble(json['amount']) ?? 0,
  );
}

class DebtResult {
  final List<DebtPerPerson> perPerson;
  final List<DebtTransfer> transfers;
  final Map<String, dynamic> bill;

  const DebtResult({
    required this.perPerson,
    required this.transfers,
    required this.bill,
  });

  factory DebtResult.fromJson(Map<String, dynamic> json) => DebtResult(
    perPerson: ((json['per_person'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(DebtPerPerson.fromJson)
        .toList(),
    transfers: ((json['transfers'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(DebtTransfer.fromJson)
        .toList(),
    bill: (json['bill'] as Map<String, dynamic>?) ?? {},
  );
}

class PaymentRecord {
  final String id;
  final String billId;
  final String fromUserId;
  final String toUserId;
  final Map<String, dynamic>? fromUser;
  final Map<String, dynamic>? toUser;
  final double amount;
  final String status;
  final String? slipUrl;
  final DateTime? createdAt;

  const PaymentRecord({
    required this.id,
    required this.billId,
    required this.fromUserId,
    required this.toUserId,
    this.fromUser,
    this.toUser,
    required this.amount,
    required this.status,
    this.slipUrl,
    this.createdAt,
  });

  bool get isConfirmed => status == 'confirmed';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
    id: (json['id'] ?? '').toString(),
    billId: (json['bill_id'] ?? '').toString(),
    fromUserId: (json['from_user_id'] ?? '').toString(),
    toUserId: (json['to_user_id'] ?? '').toString(),
    fromUser: json['from_user'] as Map<String, dynamic>?,
    toUser: json['to_user'] as Map<String, dynamic>?,
    amount: _toDouble(json['amount']) ?? 0,
    status: (json['status'] ?? 'pending').toString(),
    slipUrl: json['slip_url']?.toString(),
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null,
  );
}

// ── Service ──────────────────────────────────────────────────────────────────

/// SettlementService handles debt calculation and payment lookups.
/// HTTP mutations (create payment, confirm payment) remain in PaymentService.
class SettlementService {
  final Dio _dio;
  const SettlementService(this._dio);

  /// GET /bills/:id/debts
  /// Returns per-person breakdown, min-cash-flow transfers, and bill info.
  Future<DebtResult> getDebts(String billId) async {
    final response = await _dio.get('/bills/$billId/debts');
    return DebtResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /payments?bill_id=:id
  /// Returns all payments for a bill (pending + confirmed).
  Future<List<PaymentRecord>> listPayments(String billId) async {
    final response = await _dio.get(
      '/payments',
      queryParameters: {'bill_id': billId},
    );
    final data = response.data as Map<String, dynamic>;
    return ((data['payments'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList();
  }
}

final settlementServiceProvider = Provider<SettlementService>((ref) {
  return SettlementService(ref.read(authDioProvider));
});

// ── helpers ──────────────────────────────────────────────────────────────────

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
