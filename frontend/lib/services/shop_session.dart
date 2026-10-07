import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_service.dart';

/// ✅ គ្រប់គ្រង "Shop ដែលកំពុងប្រើ" និង "Token" តាម Shop នីមួយៗ
///
/// បញ្ហាដើម៖ នៅលើ Web, SharedPreferences = localStorage ដែលចែករំលែកគ្នារវាង
/// ​គ្រប់ Tab → Token និង shop_slug តែមួយ ត្រូវប្រើដោយ Shop ទាំងអស់។
///
/// ដំណោះស្រាយ៖
///  • Shop ដែលកំពុងប្រើ (slug) រក្សាទុកក្នុង Memory របស់ Tab នីមួយៗ
///  • Token រក្សាទុកដាច់ដោយឡែកតាម Shop: access_token_<slug>
class ShopSession {
  static const String defaultSlug = 'super-admin-shop';

  static bool _initialized = false;
  static String _slug = defaultSlug; // Shop ដែលកំពុងបង្ហាញ
  static String _authSlug = defaultSlug; // Shop ដែល Token ត្រូវបានរក្សាទុក

  static String? shopName;
  static ShopTheme? theme;

  static String get slug => _slug;
  static String get authSlug => _authSlug;

  static String _accessKey(String s) => 'access_token_$s';
  static String _refreshKey(String s) => 'refresh_token_$s';

  /// ហៅម្តងពេល App ចាប់ផ្តើម (ក្នុង main.dart)
  static Future<void> init(String? urlSlug) async {
    if (_initialized) return; // Restart/ហៅម្តងទៀត → រក្សា Shop ដដែល
    _initialized = true;

    String? slug;
    if (urlSlug != null && urlSlug.isNotEmpty) {
      slug = urlSlug; // ១. URL មុនគេ (#/ans-shop)
    } else if (!kIsWeb) {
      // ២. Mobile/Desktop៖ ប្រើ Shop ចុងក្រោយ (Web មិនប្រើ ព្រោះ Tab ចែកគ្នា)
      final prefs = await SharedPreferences.getInstance();
      slug = prefs.getString('shop_slug');
    }
    _slug = (slug == null || slug.isEmpty) ? defaultSlug : slug;
    _authSlug = _slug;
    await _persistLastSlug();
  }

  /// ប្តូរ Shop ដែលកំពុងបង្ហាញ (Token នៅដដែល)
  static Future<void> setSlug(String slug, {String? name}) async {
    if (slug.isEmpty) return;
    _slug = slug;
    if (name != null) shopName = name;
    await _persistLastSlug();
  }

  static Future<void> _persistLastSlug() async {
    if (kIsWeb) return; // Web: មិនសរសេរ localStorage ចែករំលែក
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_slug', _slug);
  }

  // ───────────── Tokens (តាម Shop) ─────────────

  static Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey(_authSlug));
  }

  static Future<bool> hasToken() async => (await accessToken()) != null;

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey(_authSlug), access);
    await prefs.setString(_refreshKey(_authSlug), refresh);
  }

  /// Logout៖ លុបតែ Token របស់ Shop នេះ — រក្សា Shop (slug) និង Theme
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey(_authSlug));
    await prefs.remove(_refreshKey(_authSlug));
    // ត្រឡប់ទៅ Shop ដើមនៃ Tab នេះ (ឧ. super admin ដែលបានប្តូរមើល Shop ផ្សេង)
    _slug = _authSlug;
    await _persistLastSlug();
  }
}
