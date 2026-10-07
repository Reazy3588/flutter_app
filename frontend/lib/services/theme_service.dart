import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'shop_session.dart';

class ShopTheme {
  final String name;
  final String slug;
  final String? logoUrl; // ✅ បន្ថែមនេះ
  final String? description; // ✅ បន្ថែមនេះ
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String currency;
  final String language;

  ShopTheme({
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    this.currency = 'USD',
    this.language = 'en',
  });

  factory ShopTheme.fromJson(Map<String, dynamic> json) {
    return ShopTheme(
      name: json['name'] ?? 'My Shop',
      slug: json['slug'] ?? '',
      logoUrl: json['logo_url'], // ✅ បន្ថែមនេះ
      description: json['description'], // ✅ បន្ថែមនេះ
      primaryColor: _hexToColor(json['primary_color'] ?? '#1F6FEB'),
      secondaryColor: _hexToColor(json['secondary_color'] ?? '#1547A8'),
      accentColor: _hexToColor(json['accent_color'] ?? '#00D2FF'),
      currency: json['currency'] ?? 'USD',
      language: json['language'] ?? 'en',
    );
  }

  factory ShopTheme.defaultTheme() {
    return ShopTheme(
      name: 'ShopEase',
      slug: 'default',
      primaryColor: const Color(0xFF1F6FEB),
      secondaryColor: const Color(0xFF1547A8),
      accentColor: const Color(0xFF00D2FF),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'logo_url': logoUrl,
      'description': description,
      'primary_color': _colorToHex(primaryColor),
      'secondary_color': _colorToHex(secondaryColor),
      'accent_color': _colorToHex(accentColor),
      'currency': currency,
      'language': language,
    };
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

class ThemeService {
  final _dio = ApiService().dio;
  static const String _shopThemeKey = 'shop_theme';

  Future<ShopTheme> fetchTheme(String slug) async {
    final res = await _dio.get('/shops/$slug/theme/');
    final theme = ShopTheme.fromJson(res.data);

    // ✅ មិនសរសេរ shop_slug ទៅ localStorage ចែករំលែកទៀតទេ (ប្រើ ShopSession)
    ShopSession.theme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_shopThemeKey}_$slug', jsonEncode(theme.toJson()));

    return theme;
  }

  Future<ShopTheme?> getCachedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeJson = prefs.getString('${_shopThemeKey}_${ShopSession.slug}');
    if (themeJson == null) return null;

    try {
      final data = jsonDecode(themeJson) as Map<String, dynamic>;
      return ShopTheme.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCachedSlug() async {
    final prefs = await SharedPreferences.getInstance();
    return ShopSession.slug;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_shopThemeKey}_${ShopSession.slug}');
  }
}
