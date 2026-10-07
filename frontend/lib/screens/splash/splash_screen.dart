import 'package:dio/dio.dart';
import '../../services/shop_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

class SplashScreen extends StatefulWidget {
  final ShopTheme? shopTheme; // ✅ បន្ថែមនេះ
  const SplashScreen({super.key, this.shopTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _blobController;
  late AnimationController _mainController;
  late AnimationController _shimmerController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;

  // ✅ ប្រើពណ៌ពី ShopTheme
  Color get _accent1 =>
      widget.shopTheme?.primaryColor ?? const Color(0xFF6366F1);
  Color get _accent2 =>
      widget.shopTheme?.secondaryColor ?? const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();

    _blobController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
      ),
    );

    _mainController.forward();
    _navigateNext();
  }

  @override
  void dispose() {
    _blobController.dispose();
    _mainController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      try {
        final user = await AuthService().getProfile();
        if (!mounted) return;

        // ✅ Load Theme តាម Shop របស់ User
        ShopTheme? userTheme = widget.shopTheme;
        if (user.shopSlug != null && user.shopSlug!.isNotEmpty) {
          try {
            userTheme = await ThemeService().fetchTheme(user.shopSlug!);
            await ShopSession.setSlug(user.shopSlug!, name: user.shopName);
            print('✅ Loaded theme for shop: ${user.shopSlug}');
          } catch (e) {
            print('⚠️ Failed to load user shop theme: $e');
          }
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              user: user,
              shopTheme: userTheme, // ✅ ប្រើ Theme ថ្មី
            ),
          ),
        );
        return;
      } catch (e) {
        // ✅ Logout ប្រសិនបើ Token ត្រូវបាន Server បដិសេធ (401/403) ប៉ុណ្ណោះ
        // បើជាបញ្ហា Network/Server (Server ធ្លាក់, CORS...) → រក្សា Session ទុក
        final status = e is DioException ? e.response?.statusCode : null;
        print('⚠️ getProfile failed (status: $status): $e');
        if (status == 401 || status == 403) {
          await AuthService().logout();
        }
      }
    }

    if (hasSeenOnboarding) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: null,
            shopTheme: widget.shopTheme,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          shopTheme: widget.shopTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ទាញយក Logo URL
    final logoUrl = widget.shopTheme?.logoUrl;
    final shopName = widget.shopTheme?.name ?? 'ShopEase';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, _) {
              return CustomPaint(
                painter: _SplashBlobPainter(
                  _blobController.value,
                  _accent1,
                  _accent2,
                ),
                size: MediaQuery.of(context).size,
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(scale: _logoScale, child: child),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _accent1.withOpacity(0.5),
                          _accent2.withOpacity(0.2),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent1.withOpacity(0.25),
                          blurRadius: 60,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child:
                            // ✅ ប្រសិនបើមាន Logo URL → បង្ហាញ Logo ពី Backend
                            logoUrl != null && logoUrl.isNotEmpty
                                ? Image.network(
                                    logoUrl,
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/rhd_logo.jpeg',
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                // ✅ ប្រសិនបើគ្មាន → ប្រើ Logo លំនាំដើម
                                : Image.asset(
                                    'assets/images/rhd_logo.jpeg',
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _textFade,
                      child:
                          SlideTransition(position: _textSlide, child: child),
                    );
                  },
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          final dx = (_shimmerController.value * 2 - 0.5) *
                              bounds.width;
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0F172A),
                              _accent1,
                              _accent2,
                              const Color(0xFF0F172A),
                            ],
                            stops: const [0.0, 0.4, 0.6, 1.0],
                            transform: GradientTranslation(dx / bounds.width),
                          ).createShader(bounds);
                        },
                        // ✅ បង្ហាញ Shop Name ជំនួស "ELEVATE YOUR STYLE"
                        child: Text(
                          shopName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ✅ បង្ហាញ Shop Description ប្រសិនបើមាន
                      if (widget.shopTheme?.description != null &&
                          widget.shopTheme!.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            widget.shopTheme!.description!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _dot(),
                            const SizedBox(width: 8),
                            const Text("Fashion",
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                )),
                            const SizedBox(width: 8),
                            _dot(),
                            const SizedBox(width: 8),
                            const Text("Tech",
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                )),
                            const SizedBox(width: 8),
                            _dot(),
                            const SizedBox(width: 8),
                            const Text("Essentials",
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                )),
                          ],
                        ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return FadeTransition(opacity: _textFade, child: child);
                  },
                  child: Column(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(_accent1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [_accent1, _accent2],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "POWERED BY RHD",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _accent1.withOpacity(0.6),
        ),
      );
}

class GradientTranslation extends GradientTransform {
  final double dx;
  const GradientTranslation(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

class _SplashBlobPainter extends CustomPainter {
  final double t;
  final Color color1;
  final Color color2;
  _SplashBlobPainter(this.t, this.color1, this.color2);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    final colors = [color1, color2, color1.withOpacity(0.5)];
    for (var i = 0; i < 3; i++) {
      final angle = t * 2 * math.pi + i * 2.1;
      final cx =
          size.width / 2 + math.cos(angle) * size.width * (0.28 + 0.05 * i);
      final cy = size.height / 2 +
          math.sin(angle * 1.3) * size.height * (0.25 + 0.04 * i);
      paint.color = colors[i].withOpacity(0.10);
      canvas.drawCircle(Offset(cx, cy), 140 + 25 * math.sin(angle), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashBlobPainter old) => old.t != t;
}
