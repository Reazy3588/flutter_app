import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/theme_service.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  const _OnboardPage(this.icon, this.title, this.subtitle, this.colors);
}

class OnboardingScreen extends StatefulWidget {
  final ShopTheme? shopTheme; // ✅ បន្ថែមនេះ
  const OnboardingScreen({super.key, this.shopTheme});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _blobController =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();
  int _page = 0;

  // ✅ ប្រើពណ៌ពី ShopTheme
  Color get _primaryColor =>
      widget.shopTheme?.primaryColor ?? const Color(0xFF6366F1);
  Color get _secondaryColor =>
      widget.shopTheme?.secondaryColor ?? const Color(0xFF8B5CF6);

  List<_OnboardPage> get _pages => [
        _OnboardPage(
          Icons.storefront_rounded,
          "Discover Products",
          "Browse thousands of products across every category with exclusive deals.",
          [_primaryColor, _secondaryColor],
        ),
        _OnboardPage(
          Icons.local_offer_rounded,
          "Great Deals & Discounts",
          "Enjoy daily promotions, coupons, and flash sales curated just for you.",
          [_secondaryColor, _primaryColor],
        ),
        _OnboardPage(
          Icons.local_shipping_rounded,
          "Fast Doorstep Delivery",
          "Track your order live in real time from checkout straight to your door.",
          [_primaryColor, _secondaryColor],
        ),
      ];

  Future<void> _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          shopTheme: widget.shopTheme, // ✅ បន្ថែមនេះ
        ),
      ),
    );
  }

  Future<void> _goToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          user: null,
          shopTheme: widget.shopTheme, // ✅ បន្ថែមនេះ
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final page = pages[_page];
    final isLast = _page == pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, _) {
              return CustomPaint(
                painter: _BlobPainter(_blobController.value, page.colors),
                size: MediaQuery.of(context).size,
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ✅ បង្ហាញ Logo តូចនៅខាងឆ្វេង
                      if (widget.shopTheme?.logoUrl != null)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              widget.shopTheme!.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.store,
                                color: _primaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(),
                      GestureDetector(
                        onTap: _goToHome,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            "Skip",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final p = pages[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(48),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [p.colors[0], p.colors[1]],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.colors[0].withOpacity(0.35),
                                      blurRadius: 40,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child:
                                    Icon(p.icon, size: 72, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 56),
                            Text(
                              p.title,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              p.subtitle,
                              style: TextStyle(
                                color: const Color(0xFF64748B).withOpacity(0.9),
                                fontSize: 15,
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pages.length, (i) {
                    final selected = _page == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: selected ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? LinearGradient(colors: page.colors)
                            : null,
                        color: selected ? null : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(colors: page.colors),
                        boxShadow: [
                          BoxShadow(
                            color: page.colors[0].withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (isLast) {
                            _goToLogin();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? "Get Started" : "Continue",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 20, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  _BlobPainter(this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    for (var i = 0; i < 3; i++) {
      final angle = t * 2 * math.pi + i * 2.1;
      final cx =
          size.width / 2 + math.cos(angle) * size.width * (0.25 + 0.05 * i);
      final cy = size.height / 2 +
          math.sin(angle * 1.3) * size.height * (0.22 + 0.04 * i);
      paint.color = colors[i % colors.length].withOpacity(0.12);
      canvas.drawCircle(Offset(cx, cy), 130 + 20 * math.sin(angle), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.t != t || old.colors != colors;
}
