import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class BillService {
  final Dio _dio;
  const BillService(this._dio);

  // ── Bills ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createBill({
    required String name,
    required DateTime date,
    required double vatPercent,
    double? serviceChargePercent,
  }) async {
    final response = await _dio.post(
      '/bills',
      data: {
        'name': name,
        'date': date.toIso8601String(),
        'vat_pct': vatPercent,
        'service_charge_pct': ?serviceChargePercent,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listBills() async {
    final response = await _dio.get('/bills');
    final data = response.data as Map<String, dynamic>;
    return (data['bills'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getBill(String billId) async {
    final response = await _dio.get('/bills/$billId');
    return response.data as Map<String, dynamic>;
  }

  Future<void> setPayer({required String billId, required String payerId}) async {
    await _dio.patch('/bills/$billId/payer', data: {'paid_by': payerId});
  }

  Future<void> deleteBill(String billId) async {
    await _dio.delete('/bills/$billId');
  }

  Future<void> settleBill(String billId) async {
    await _dio.post('/bills/$billId/settle');
  }

  // ── Items ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addItem({
    required String billId,
    required String name,
    required int quantity,
    required double unitPrice,
  }) async {
    final response = await _dio.post(
      '/bills/$billId/items',
      data: {'name': name, 'quantity': quantity, 'unit_price': unitPrice},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>).first as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> addItemsBulk({
    required String billId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _dio.post(
      '/bills/$billId/items',
      data: {'items': items},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateItem({
    required String billId,
    required String itemId,
    String? name,
    int? quantity,
    double? unitPrice,
  }) async {
    final response = await _dio.put(
      '/bills/$billId/items/$itemId',
      data: {
        'name': ?name,
        'quantity': ?quantity,
        'unit_price': ?unitPrice,
      },
    );
    return (response.data as Map<String, dynamic>)['item'] as Map<String, dynamic>;
  }

  Future<void> deleteItem({
    required String billId,
    required String itemId,
  }) async {
    await _dio.delete('/bills/$billId/items/$itemId');
  }

  Future<void> assignItem({
    required String billId,
    required String itemId,
    required String userId,
  }) async {
    await _dio.post('/bills/$billId/items/$itemId/assign', data: {'user_id': userId});
  }

  Future<void> unassignItem({
    required String billId,
    required String itemId,
    required String userId,
  }) async {
    await _dio.delete('/bills/$billId/items/$itemId/assign/$userId');
  }

  Future<Map<String, dynamic>> getDebts(String billId) async {
    final response = await _dio.get('/bills/$billId/debts');
    return response.data as Map<String, dynamic>;
  }

  // ── OCR ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> runOcr({
    required String billId,
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final response = await _dio.post('/bills/$billId/ocr', data: formData);
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }
}

final billServiceProvider = Provider<BillService>((ref) {
  return BillService(ref.read(authDioProvider));
});
