import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/banner_model.dart';

/// Banner carousel — ទាញរូបពី Backend, auto-slide, មាន dots indicator។
/// បើ banners ទទេ → បង្ហាញ banner default។
class PromoBanner extends StatefulWidget {
  final List<BannerModel> banners;
  final ValueChanged<BannerModel>? onBannerTap;

  // Fallback (ពេលគ្មាន banner ពី backend)
  final String badgeText;
  final String title;
  final String buttonText;
  final VoidCallback? onButtonTap;
  final Color accent;

  const PromoBanner({
    super.key,
    this.banners = const [],
    this.onBannerTap,
    this.badgeText = "Best Seller!",
    required this.title,
    this.buttonText = "Shop Now",
    this.onButtonTap,
    this.accent = const Color(0xFF2563EB),
  });

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant PromoBanner old) {
    super.didUpdateWidget(old);

    if (old.banners.length != widget.banners.length) {
      _index = 0;

      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }

      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();

    if (widget.banners.length < 2) return;

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || !_controller.hasClients) return;

        final next = (_index + 1) % widget.banners.length;

        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = (c.maxWidth * 0.46).clamp(170.0, 280.0);
        final hasBanners = widget.banners.isNotEmpty;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: hasBanners
                    ? PageView.builder(
                        controller: _controller,
                        itemCount: widget.banners.length,
                        onPageChanged: (i) {
                          setState(() => _index = i);
                        },
                        itemBuilder: (_, i) => _BannerSlide(
                          banner: widget.banners[i],
                          accent: widget.accent,
                          onTap: () {
                            widget.onBannerTap?.call(widget.banners[i]);
                          },
                        ),
                      )
                    : _FallbackSlide(
                        badgeText: widget.badgeText,
                        title: widget.title,
                        buttonText: widget.buttonText,
                        accent: widget.accent,
                        onTap: widget.onButtonTap,
                      ),
              ),

              // Dots indicator
              if (widget.banners.length > 1)
                Positioned(
                  left: 20,
                  bottom: 12,
                  child: Row(
                    children: List.generate(
                      widget.banners.length,
                      (i) {
                        final active = i == _index;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 5),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// BANNER SLIDE
// ============================================================

class _BannerSlide extends StatelessWidget {
  final BannerModel banner;
  final Color accent;
  final VoidCallback onTap;

  const _BannerSlide({
    required this.banner,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = banner.image != null && banner.image!.isNotEmpty;

    final hasText = banner.title.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (hasImage)
              Image.network(
                banner.image!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return Container(
                    color: const Color(0xFFE9ECF3),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: Colors.white,
                  );
                },
              )
            else
              Container(
                color: Colors.white,
              ),

            // Text
            if (hasText)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  28,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner.badgeText.isNotEmpty) ...[
                      _GlassBadge(
                        text: banner.badgeText,
                      ),
                      const SizedBox(height: 8),
                    ],
                    FractionallySizedBox(
                      widthFactor: 0.62,
                      child: Text(
                        banner.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: 0.62,
                        child: Text(
                          banner.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _CtaButton(
                      text: banner.buttonText,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FALLBACK SLIDE
// ============================================================

class _FallbackSlide extends StatelessWidget {
  final String badgeText;
  final String title;
  final String buttonText;
  final Color accent;
  final VoidCallback? onTap;

  const _FallbackSlide({
    required this.badgeText,
    required this.title,
    required this.buttonText,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassBadge(
                  text: badgeText,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onTap,
                  child: _CtaButton(
                    text: buttonText,
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

// ============================================================
// GLASS BADGE
// ============================================================

class _GlassBadge extends StatelessWidget {
  final String text;

  const _GlassBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: Colors.amber,
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CTA BUTTON
// ============================================================

class _CtaButton extends StatelessWidget {
  final String text;

  const _CtaButton({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        14,
        7,
        8,
        7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1E2025),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF1E2025),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
