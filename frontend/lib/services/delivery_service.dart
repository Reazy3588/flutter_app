import 'package:dio/dio.dart';
import '../models/delivery_order_model.dart';
import 'api_service.dart';

class DeliveryService {
  final _dio = ApiService().dio;

  /// ទាញបញ្ជី Order តាម Status
  Future<List<DeliveryOrderModel>> getOrders({String? status}) async {
    final response = await _dio.get(
      '/products/delivery/orders/', // ✅ ដក /api ចេញ
      queryParameters: status != null ? {'status': status} : null,
    );
    return (response.data as List)
        .map((e) => DeliveryOrderModel.fromJson(e))
        .toList();
  }

  /// ទាញលម្អិត Order មួយ
  Future<DeliveryOrderModel> getOrderDetail(String orderNumber) async {
    final response = await _dio.get(
      '/products/delivery/orders/$orderNumber/', // ✅ ដក /api ចេញ
    );
    return DeliveryOrderModel.fromJson(response.data);
  }

  /// Update Status
  Future<DeliveryOrderModel> updateStatus({
    required String orderNumber,
    required String status,
    String? reason,
  }) async {
    final response = await _dio.post(
      '/products/delivery/orders/$orderNumber/status/', // ✅ ដក /api ចេញ
      data: {
        'status': status,
        if (reason != null) 'reason': reason,
      },
    );
    return DeliveryOrderModel.fromJson(response.data);
  }

  /// Update GPS Location
  Future<void> updateLocation({
    required String orderNumber,
    required double lat,
    required double lng,
  }) async {
    await _dio.post(
      '/products/delivery/orders/$orderNumber/location/', // ✅ ដក /api ចេញ
      data: {'lat': lat, 'lng': lng},
    );
  }

  /// ទាញ Stats
  Future<Map<String, dynamic>> getStats() async {
    final response = await _dio.get(
      '/products/delivery/stats/', // ✅ ដក /api ចេញ
    );
    return response.data;
  }
  // lib/services/delivery_service.dart

  Future<Map<String, dynamic>> getEarnings() async {
    final response = await _dio.get('/products/delivery/earnings/');
    return response.data;
  }
}
