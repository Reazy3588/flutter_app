import 'package:dio/dio.dart';
import '../models/cart.dart';
import 'api_service.dart';

class CartService {
  final ApiService _api = ApiService();

  Future<Cart> getCart() async {
    final res = await _api.dio.get('/products/cart/');
    return Cart.fromJson(res.data);
  }

  Future<int> addToCart(
    String slug, {
    int quantity = 1,
    int? variantId, // ✅ បន្ថែម
  }) async {
    try {
      final res = await _api.dio.post(
        '/products/cart/add/',
        data: {
          'slug': slug,
          'quantity': quantity,
          if (variantId != null) 'variant_id': variantId, // ✅
        },
      );
      return (res.data['count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['error'] != null) {
        throw Exception(e.response!.data['error']);
      }
      rethrow;
    }
  }

  Future<void> updateQuantity(int itemId, int quantity) async {
    try {
      await _api.dio.patch(
        '/products/cart/$itemId/',
        data: {'quantity': quantity},
      );
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['error'] != null) {
        throw Exception(e.response!.data['error']);
      }
      rethrow;
    }
  }

  Future<void> deleteItem(int itemId) async {
    try {
      // ✅ ត្រូវការ '/delete/' នៅខាងចុង
      await _api.dio.delete('/products/cart/$itemId/delete/');
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['error'] != null) {
        throw Exception(e.response!.data['error']);
      }
      rethrow;
    }
  }

  Future<bool> toggleWishlist(String slug) async {
    final res = await _api.dio.post('/products/wishlist/$slug/toggle/');
    return res.data['wishlisted'] as bool;
  }
}
