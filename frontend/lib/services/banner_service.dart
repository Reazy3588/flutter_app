import '../models/banner_model.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class BannerService {
  final _dio = ApiService().dio;

  String? _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    final path = imagePath.startsWith('/') ? imagePath : '/$imagePath';
    return '${AppConstants.mediaBaseUrl}$path';
  }

  /// GET /api/products/banners/?shop=<slug>
  /// បើ Error → ត្រឡប់ list ទទេ (Home មិនគាំង ហើយបង្ហាញ banner default)
  Future<List<BannerModel>> getBanners({String? shopSlug}) async {
    try {
      final response = await _dio.get(
        AppConstants.bannersEndpoint,
        queryParameters: {
          if (shopSlug != null && shopSlug.isNotEmpty) 'shop': shopSlug,
        },
      );
      final data = response.data;
      final List results = data is Map ? (data['results'] ?? []) : data;
      return results.map((e) {
        final json = Map<String, dynamic>.from(e);
        json['image'] = _buildImageUrl(json['image']);
        return BannerModel.fromJson(json);
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
