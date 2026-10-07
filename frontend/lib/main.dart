import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash/splash_screen.dart';
import 'services/theme_service.dart';
import 'services/shop_session.dart';
import 'services/chat_notification_service.dart';

void main() {
  runApp(const EcommerceApp());
}

class EcommerceApp extends StatefulWidget {
  const EcommerceApp({super.key});

  @override
  State<EcommerceApp> createState() => _EcommerceAppState();
}

class _EcommerceAppState extends State<EcommerceApp>
    with WidgetsBindingObserver {
  ShopTheme? _shopTheme;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatNotificationService().stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatNotificationService().startPolling();
    } else if (state == AppLifecycleState.paused) {
      ChatNotificationService().stopPolling();
    }
  }

  // ✅ ទាញ Shop Slug ពី URL Hash ឱ្យបានត្រឹមត្រូវ
  String? _getShopSlugFromUrl() {
    try {
      // ✅ ប្រើ Uri.base ដើម្បីអាន URL
      final uri = Uri.base;
      print('🔵 Full URL: ${uri.toString()}');
      print('🔵 Fragment: ${uri.fragment}');
      print('🔵 Path: ${uri.path}');
      print('🔵 Query: ${uri.query}');

      // ✅ ពិនិត្យ Fragment (#/ans-shop)
      if (uri.fragment.isNotEmpty) {
        String fragment = uri.fragment;

        // លុប / នៅខាងចុង
        fragment = fragment.replaceAll('/', '').trim();

        // បើមាន ? ក្នុង fragment → យកតែផ្នែកខាងមុខ
        if (fragment.contains('?')) {
          fragment = fragment.split('?').first;
        }

        if (fragment.isNotEmpty) {
          print('✅ Shop Slug from Fragment: $fragment');
          return fragment;
        }
      }

      // ✅ ពិនិត្យ Path (សម្រាប់ Path URL ដូចជា /ans-shop)
      if (uri.path.isNotEmpty && uri.path != '/') {
        final path = uri.path.replaceAll('/', '').trim();
        if (path.isNotEmpty) {
          print('✅ Shop Slug from Path: $path');
          return path;
        }
      }

      return null;
    } catch (e) {
      print('❌ URL Parse Error: $e');
      return null;
    }
  }

  Future<void> _loadTheme() async {
    try {
      // ✅ Shop ដែលកំពុងប្រើ កំណត់ពី URL (#/ans-shop) ក្នុង Tab នីមួយៗ
      // Web: ប្រសិនបើគ្មាន URL → super-admin-shop (មិនអានពី localStorage ចែករំលែក)
      await ShopSession.init(_getShopSlugFromUrl());
      final shopSlug = ShopSession.slug;
      print('🎯 Final Shop Slug: $shopSlug');

      final theme = await ThemeService().fetchTheme(shopSlug);

      if (!mounted) return;
      setState(() {
        _shopTheme = theme;
        _loading = false;
      });

      // ✅ ចាប់ផ្តើម Chat Polling
      ChatNotificationService().startPolling();
    } catch (e) {
      print('❌ Error loading theme: $e');
      if (!mounted) return;
      setState(() {
        _shopTheme = ShopTheme.defaultTheme();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1F6FEB),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: _shopTheme!.name,
      debugShowCheckedModeBanner: false,
      navigatorKey: ChatNotificationService.navigatorKey,
      theme: ThemeData(
        primaryColor: _shopTheme!.primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _shopTheme!.primaryColor,
          primary: _shopTheme!.primaryColor,
          secondary: _shopTheme!.secondaryColor,
        ),
        useMaterial3: true,
      ),
      home: SplashScreen(shopTheme: _shopTheme),
    );
  }
}
