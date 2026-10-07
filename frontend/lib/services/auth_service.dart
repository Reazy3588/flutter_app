// lib/services/auth_service.dart

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'api_service.dart';
import 'shop_session.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _dio = ApiService().dio;

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required String password2,
    String? shopSlug,
  }) async {
    final response = await _dio.post(AppConstants.registerEndpoint, data: {
      "full_name": fullName,
      "phone_number": phoneNumber,
      "email": email,
      "password": password,
      "password2": password2,
      if (shopSlug != null && shopSlug.isNotEmpty) "shop_slug": shopSlug,
    });
    return response.data;
  }

  /// Step 2: submit the 6-digit code the user received by SMS.
  /// On success, the backend also logs the user in immediately
  /// (activates the account + returns JWT tokens), so we save the
  /// tokens here too and return the UserModel — ready for Home screen.
  Future<UserModel> verifyOtp({
    required String phoneNumber,
    required String code,
    String? shopSlug, // ✅ បន្ថែម
  }) async {
    final response = await _dio.post(AppConstants.verifyOtpEndpoint, data: {
      "phone_number": phoneNumber,
      "code": code,
      if (shopSlug != null && shopSlug.isNotEmpty)
        "shop_slug": shopSlug, // ✅ បន្ថែម
    });

    return _finishAuth(response.data);
  }

  Future<Map<String, dynamic>> resendOtp({required String phoneNumber}) async {
    final response = await _dio.post(AppConstants.resendOtpEndpoint, data: {
      "phone_number": phoneNumber,
    });
    return response.data;
  }

  /// Step 1 of Forgot Password
  Future<Map<String, dynamic>> requestPasswordReset({
    required String phoneNumber,
  }) async {
    final response =
        await _dio.post(AppConstants.forgotPasswordEndpoint, data: {
      "phone_number": phoneNumber,
    });
    return response.data;
  }

  /// Step 2 of Forgot Password
  Future<UserModel> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
    required String newPassword2,
  }) async {
    final response = await _dio.post(AppConstants.resetPasswordEndpoint, data: {
      "phone_number": phoneNumber,
      "code": code,
      "new_password": newPassword,
      "new_password2": newPassword2,
    });

    return _finishAuth(response.data);
  }

  /// Login with EITHER email or phone number + password.
  /// ✅ បញ្ជូន shop_slug ទៅ Backend ដើម្បីឱ្យវាដឹងថាត្រូវយក Account ណាមួយ
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    // ✅ ប្រើ Shop របស់ Tab នេះ (មិនមែនពី localStorage ចែករំលែក)
    final shopSlug = ShopSession.slug;

    final response = await _dio.post(AppConstants.loginEndpoint, data: {
      "identifier": identifier,
      "password": password,
      if (shopSlug.isNotEmpty) "shop_slug": shopSlug,
    });

    return _finishAuth(response.data);
  }

  /// ✅ រក្សាទុក Token តាម Shop + ប្តូរ Shop បើជា Shop Owner
  Future<UserModel> _finishAuth(dynamic data) async {
    await ShopSession.saveTokens(data['access'], data['refresh']);
    final user = UserModel.fromJson(data['user']);
    if (user.shopSlug != null && user.shopSlug!.isNotEmpty) {
      await ShopSession.setSlug(user.shopSlug!, name: user.shopName);
    }
    return user;
  }

  /// Fetches the current logged-in user's profile
  Future<UserModel> getProfile() async {
    final response = await _dio.get(AppConstants.profileEndpoint);
    return UserModel.fromJson(response.data);
  }

  /// Update Profile
  Future<UserModel> updateProfile({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
    String? password,
    String? password2,
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    dynamic data;
    if (photoBytes != null) {
      data = FormData.fromMap({
        if (fullName != null) "full_name": fullName,
        if (email != null) "email": email,
        if (phoneNumber != null) "phone_number": phoneNumber,
        if (address != null) "address": address,
        if (password != null) "password": password,
        if (password2 != null) "password2": password2,
        "profile_photo": MultipartFile.fromBytes(
          photoBytes,
          filename: photoFilename ?? "profile_photo.jpg",
        ),
      });
    } else {
      data = {
        if (fullName != null) "full_name": fullName,
        if (email != null) "email": email,
        if (phoneNumber != null) "phone_number": phoneNumber,
        if (address != null) "address": address,
        if (password != null) "password": password,
        if (password2 != null) "password2": password2,
      };
    }

    final response = await _dio.patch(AppConstants.profileEndpoint, data: data);
    return UserModel.fromJson(response.data);
  }

  Future<void> logout() async {
    // ✅ លុបតែ Token របស់ Shop នេះ — រក្សា shop_slug ដើម្បីឱ្យ Login នៅ Shop ដដែល
    await ShopSession.clearTokens();
  }

  Future<bool> isLoggedIn() async {
    return ShopSession.hasToken();
  }

  static const String _googleClientId =
      '290619825994-ac0mrvhj4cc6s2k90roa2h8152u6kv17.apps.googleusercontent.com';

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: _googleClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("Google Sign-In cancelled");
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      final Map<String, dynamic> requestData = {};

      if (idToken != null) {
        requestData['token'] = idToken;
      } else if (accessToken != null) {
        requestData['access_token'] = accessToken;
      } else {
        throw Exception("Failed to get Google tokens");
      }

      final response = await _dio.post('/auth/google/', data: requestData);

      final data = response.data;
      final user = await _finishAuth(data);

      return {
        'user': user,
        'needs_password': data['needs_password'] ?? false,
      };
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      rethrow;
    }
  }
}
