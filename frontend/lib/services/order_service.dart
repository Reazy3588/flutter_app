import 'package:dio/dio.dart';
import '../models/order_model.dart';
import '../models/admin_order_model.dart';
import 'api_service.dart';

class OrderService {
  final Dio _dio = ApiService().dio;

  /// POST /api/products/checkout/
  Future<OrderModel> checkout({
    required int addressId,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final res = await _dio.post('/products/checkout/', data: {
      'address_id': addressId,
      'payment_method': paymentMethod,
      if (couponCode != null && couponCode.isNotEmpty)
        'coupon_code': couponCode,
    });
    return OrderModel.fromJson(res.data);
  }

  /// POST /api/products/validate-coupon/
  Future<Map<String, dynamic>> validateCoupon(String code) async {
    final res = await _dio.post('/products/validate-coupon/', data: {
      'code': code,
    });
    return res.data;
  }

  /// GET /api/products/orders/
  Future<List<OrderModel>> getOrders({String? status}) async {
    final res = await _dio.get('/products/orders/',
        queryParameters: status != null ? {'status': status} : null);
    final data = res.data;
    final List results =
        (data is List) ? data : (data['results'] as List? ?? []);
    return results.map((e) => OrderModel.fromJson(e)).toList();
  }

  /// GET /api/products/orders/<order_number>/
  Future<OrderModel> getOrderDetail(String orderNumber) async {
    final res = await _dio.get('/products/orders/$orderNumber/');
    return OrderModel.fromJson(res.data);
  }

  /// POST /api/products/orders/<order_number>/cancel/
  Future<OrderModel> cancelOrder(String orderNumber,
      {String reason = ''}) async {
    final res = await _dio.post('/products/orders/$orderNumber/cancel/',
        data: {'reason': reason});
    return OrderModel.fromJson(res.data);
  }

  /// POST /api/products/aba/generate-qr/
  Future<Map<String, dynamic>> generateAbaQr({
    required double amount,
    required String tranId,
  }) async {
    final res = await _dio.post('/products/aba/generate-qr/', data: {
      'amount': amount,
      'tran_id': tranId,
    });
    return res.data;
  }

  /// POST /api/products/aba/check-transaction/
  Future<Map<String, dynamic>> checkAbaTransaction(String tranId) async {
    final res = await _dio.post('/products/aba/check-transaction/', data: {
      'tran_id': tranId,
    });
    return res.data;
  }

  // ===================== ADMIN / DELIVERY =====================

  Future<List<AdminOrderModel>> getAdminOrders({String? status}) async {
    final res = await _dio.get('/products/admin/orders/',
        queryParameters: status != null ? {'status': status} : null);
    final data = res.data;
    final List results =
        (data is List) ? data : (data['results'] as List? ?? []);
    return results.map((e) => AdminOrderModel.fromJson(e)).toList();
  }

  Future<void> updateOrderStatus(String orderNumber, String newStatus) async {
    await _dio.post('/products/admin/orders/$orderNumber/status/',
        data: {'status': newStatus});
  }
}
