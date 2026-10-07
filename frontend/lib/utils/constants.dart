class AppConstants {
  // Change this to your Django server address.
  //
  // - Web (Chrome)      -> use 127.0.0.1  (this is the default below)
  // - iOS Simulator     -> use 127.0.0.1 or localhost
  // - Android Emulator  -> use 10.0.2.2  (this points to your computer's localhost)
  // - Real phone        -> use your computer's LAN IP, e.g. 192.168.1.10
  //   (phone and computer must be on the same Wi-Fi network)
  static const String baseUrl = "http://127.0.0.1:8000/api";
  // ✅ បន្ថែមនេះ — Base URL សម្រាប់ Media រូបភាព
  static const String mediaBaseUrl = "http://127.0.0.1:8000";

  static const String googleMapsApiKey =
      'AIzaSyAje_y198QR-JHTMPmxTY_ayG4awwB9n-c';

  static const String registerEndpoint = "$baseUrl/auth/register/";
  static const String verifyOtpEndpoint = "$baseUrl/auth/verify-otp/";
  static const String resendOtpEndpoint = "$baseUrl/auth/resend-otp/";
  static const String forgotPasswordEndpoint = '/auth/forgot-password/';
  static const String resetPasswordEndpoint = '/auth/reset-password/';
  static const String loginEndpoint = "$baseUrl/auth/login/";
  static const String profileEndpoint = "$baseUrl/auth/profile/";

  static const String categoriesEndpoint = "$baseUrl/products/categories/";
  static const String productsEndpoint = "$baseUrl/products/products/";
  static const String bannersEndpoint = "$baseUrl/products/banners/";

  static const String accessTokenKey = "access_token";
  static const String refreshTokenKey = "refresh_token";

  // Wishlist & Cart
  static const String wishlistEndpoint = "$baseUrl/products/wishlist/";
  static String wishlistToggleEndpoint(String slug) =>
      "$baseUrl/products/wishlist/$slug/toggle/";
  static const String cartEndpoint = "$baseUrl/products/cart/";
  static const String cartAddEndpoint = "$baseUrl/products/cart/add/";
}
