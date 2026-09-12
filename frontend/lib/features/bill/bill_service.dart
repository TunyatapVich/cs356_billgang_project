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
        'date': date.toIso8601String().substring(0, 10),
        'vat_pct': vatPercent,
        'service_charge_pct': serviceChargePercent ?? 0.0,
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

  Future<Map<String, dynamic>> updateBill(
    String billId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch('/bills/$billId', data: data);
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

  Future<Map<String, dynamic>> markBillPaid(String billId) async {
    final response = await _dio.post('/bills/$billId/mark-paid', data: {});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMember(String billId, [String? name]) async {
    final response = await _dio.post(
      '/bills/$billId/members',
      data: name != null && name.trim().isNotEmpty ? {'name': name.trim()} : {},
    );
    return response.data as Map<String, dynamic>;
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

  Future<void> setItemAssignments({
    required String billId,
    required String itemId,
    required List<Map<String, dynamic>> assignments,
  }) async {
    await _dio.put(
      '/bills/$billId/items/$itemId/assignments',
      data: {'assignments': assignments},
    );
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

  Future<Map<String, dynamic>> confirmLocalPayment({
    required String billId,
    required String fromUserId,
    required String toUserId,
  }) async {
    final response = await _dio.post(
      '/payments/local-confirm',
      data: {
        'bill_id': billId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── OCR ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> runOcr({
    required String billId,
    required String rawText,
    String? imageUrl,
    List<int>? imageBytes,
    String? imageMimeType,
  }) async {
    final payload = <String, dynamic>{'raw_text': rawText};
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (imageBytes != null) {
      final imageExt = imageMimeType == 'image/png'
          ? 'png'
          : imageMimeType == 'image/webp'
              ? 'webp'
              : 'jpg';
      final contentType = imageMimeType == 'image/png'
          ? DioMediaType('image', 'png')
          : imageMimeType == 'image/webp'
              ? DioMediaType('image', 'webp')
              : DioMediaType('image', 'jpeg');
      payload['image'] = MultipartFile.fromBytes(
        imageBytes,
        filename: 'receipt.$imageExt',
        contentType: contentType,
      );
    }
    final formData = FormData.fromMap(payload);

    final response = await _dio.post(
      '/bills/$billId/ocr',
      data: formData,
    );
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }
}

final billServiceProvider = Provider<BillService>((ref) {
  return BillService(ref.read(authDioProvider));
});
