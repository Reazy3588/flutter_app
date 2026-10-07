import 'package:dio/dio.dart';
import 'api_service.dart';

class ShopService {
  final _dio = ApiService().dio;

  Future<Map<String, dynamic>> getMyShop() async {
    final res = await _dio.get('/shops/me/');
    return res.data;
  }

  Future<Map<String, dynamic>> updateMyShop({
    String? name,
    String? description,
    String? phone,
    String? email,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    List<int>? logoBytes,
    String? logoFilename,
  }) async {
    dynamic data;

    if (logoBytes != null) {
      data = FormData.fromMap({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (primaryColor != null) 'primary_color': primaryColor,
        if (secondaryColor != null) 'secondary_color': secondaryColor,
        if (accentColor != null) 'accent_color': accentColor,
        'logo': MultipartFile.fromBytes(
          logoBytes,
          filename: logoFilename ?? 'shop_logo.jpg',
        ),
      });
    } else {
      data = {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (primaryColor != null) 'primary_color': primaryColor,
        if (secondaryColor != null) 'secondary_color': secondaryColor,
        if (accentColor != null) 'accent_color': accentColor,
      };
    }

    final res = await _dio.patch('/shops/me/', data: data);
    return res.data;
  }
}
