import 'package:dio/dio.dart';
import '../utils/constants.dart';
import 'shop_session.dart';

/// Small wrapper around Dio that automatically attaches the
/// saved JWT access token to every request (once logged in).
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;

  ApiService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {"Content-Type": "application/json"},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // ✅ Token តាម Shop (ដាច់ពីគ្នារវាង Shop)
        final token = await ShopSession.accessToken();
        if (token != null) {
          options.headers["Authorization"] = "Bearer $token";
        }
        return handler.next(options);
      },
    ));
  }
}

/// Reads the error message returned by Django REST Framework
/// (which can be a string, a list, or a dict of field errors)
/// and turns it into one readable String for showing in a SnackBar.
String extractErrorMessage(Object error) {
  if (error is DioException && error.response?.data != null) {
    final data = error.response!.data;
    if (data is Map) {
      final firstKey = data.keys.first;
      final value = data[firstKey];
      if (value is List) return value.first.toString();
      return value.toString();
    }
    return data.toString();
  }
  return "Something went wrong. Please check your network connection.";
}
