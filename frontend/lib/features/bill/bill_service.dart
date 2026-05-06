import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// BillService only knows about HTTP calls for bills and bill items.
// Keep state, validation, and navigation in providers/screens.
class BillService {
  final Dio _dio;
  const BillService(this._dio);

  Future<Map<String, dynamic>> createBill({
    required String name,
    required DateTime date,
    required double vatPercent,
  }) async {
    final response = await _dio.post(
      '/bills/create',
      data: {
        'name': name,
        'date': date.toIso8601String(),
        'vat_pct': vatPercent,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listBills() async {
    final response = await _dio.get('/bills');
    final data = response.data as Map<String, dynamic>;
    final bills = data['bills'] as List<dynamic>;

    return bills.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> deleteBill(String billId) async {
    final response = await _dio.delete('/bills/$billId');
    return response.data as Map<String, dynamic>;
  }
}

final billServiceProvider = Provider<BillService>((ref) {
  return BillService(ref.read(authDioProvider));
});
