import '../models/category_model.dart';
import '../models/product_model.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class ProductService {
  final _dio = ApiService().dio;

  /// ✅ Helper: បំប្លែង Image Path ទៅជា Full URL
  String? _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    // បើជា Full URL រួចហើយ → ត្រឡប់ដូចដើម
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    // បើជា Relative Path → ភ្ជាប់ជាមួយ mediaBaseUrl
    final path = imagePath.startsWith('/') ? imagePath : '/$imagePath';
    return '${AppConstants.mediaBaseUrl}$path';
  }

  /// GET /api/products/categories/
  Future<List<CategoryModel>> getCategories({String? shopSlug}) async {
    final response = await _dio.get(
      AppConstants.categoriesEndpoint,
      queryParameters: {
        if (shopSlug != null && shopSlug.isNotEmpty) 'shop': shopSlug,
      },
    );
    final List results = response.data['results'];
    return results.map((json) => CategoryModel.fromJson(json)).toList();
  }

  /// GET /api/products/products/
  Future<List<ProductModel>> getProducts({
    String? categorySlug,
    String? search,
    String? ordering,
    bool? isNewArrival,
    bool? isBestSeller,
    bool? isRecommended,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? shopSlug,
  }) async {
    final response = await _dio.get(
      AppConstants.productsEndpoint,
      queryParameters: {
        if (categorySlug != null) 'category__slug': categorySlug,
        if (search != null && search.isNotEmpty) 'search': search,
        if (ordering != null) 'ordering': ordering,
        if (isNewArrival != null) 'is_new_arrival': isNewArrival,
        if (isBestSeller != null) 'is_best_seller': isBestSeller,
        if (isRecommended != null) 'is_recommended': isRecommended,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (minRating != null && minRating > 0) 'min_rating': minRating,
        if (shopSlug != null && shopSlug.isNotEmpty) 'shop': shopSlug,
      },
    );
    final List results = response.data['results'];
    return results.map((json) {
      // ✅ បំប្លែង image មុននឹងបង្កើត ProductModel
      if (json['image'] != null) {
        json['image'] = _buildImageUrl(json['image']);
      }
      return ProductModel.fromJson(json);
    }).toList();
  }

  Future<List<ProductModel>> getPopularProducts({String? shopSlug}) {
    return getProducts(ordering: '-sold_count', shopSlug: shopSlug);
  }

  Future<List<ProductModel>> getNewArrivals({String? shopSlug}) {
    return getProducts(
        isNewArrival: true, ordering: '-created_at', shopSlug: shopSlug);
  }

  Future<List<ProductModel>> getBestSellers({String? shopSlug}) {
    return getProducts(
        isBestSeller: true, ordering: '-sold_count', shopSlug: shopSlug);
  }

  Future<List<ProductModel>> getRecommended({String? shopSlug}) {
    return getProducts(isRecommended: true, shopSlug: shopSlug);
  }

  Future<ProductModel> getProductDetail(String slug) async {
    final res = await _dio.get('/products/products/$slug/');
    final json = res.data;
    // ✅ បំប្លែង image និង gallery_images
    if (json['image'] != null) {
      json['image'] = _buildImageUrl(json['image']);
    }
    if (json['gallery_images'] != null) {
      json['gallery_images'] = (json['gallery_images'] as List).map((e) {
        if (e is Map && e['image'] != null) {
          e['image'] = _buildImageUrl(e['image']);
        }
        return e;
      }).toList();
    }
    return ProductModel.fromJson(json);
  }

  Future<List<ProductModel>> getWishlist() async {
    final res = await _dio.get('/products/wishlist/');
    final List results = res.data;
    return results.map((json) {
      // ✅ បំប្លែង image សម្រាប់ Wishlist ដែរ
      if (json['image'] != null) {
        json['image'] = _buildImageUrl(json['image']);
      }
      return ProductModel.fromJson(json);
    }).toList();
  }
}
