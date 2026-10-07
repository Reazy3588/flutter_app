import 'dart:ui';
import 'package:flutter/material.dart';

class MainBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  /// ✅ ចំនួន Badge សម្រាប់ Wishlist
  final int wishlistCount;

  /// ✅ ចំនួន Badge សម្រាប់ Orders (Active Orders)
  final int orderCount;

  /// ✅ ចំនួន Chat ដែលមិនទាន់អាន (បង្ហាញលើ Orders Tab)
  final int chatUnreadCount;

  /// ✅ ពណ៌ Theme របស់ Shop
  final Color? primaryColor;

  const MainBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.wishlistCount = 0,
    this.orderCount = 0,
    this.chatUnreadCount = 0, // ✅ បន្ថែម
    this.primaryColor,
  });

  // ✅ Nav Bar: Home | Shop | Wishlist | Orders | Profile
  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      label: 'Shop',
    ),
    _NavItem(
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite_rounded,
      label: 'Wishlist',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = primaryColor ?? const Color(0xFF1F6FEB);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.55)
                    : Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (index) {
                  final item = _items[index];
                  final isSelected = selectedIndex == index;

                  // ✅ Badge Logic
                  int badgeCount = 0;
                  if (index == 2) badgeCount = wishlistCount;
                  if (index == 3) {
                    // ✅ Orders Tab: បង្ហាញ Chat Unread + Active Orders
                    badgeCount = chatUnreadCount + orderCount;
                  }

                  return Expanded(
                    child: _NavButton(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => onTap(index),
                      primaryColor: primary,
                      badgeCount: badgeCount,
                      // ✅ ពណ៌ Badge ខុសគ្នាតាម Tab
                      badgeColor: index == 3 && chatUnreadCount > 0
                          ? const Color(0xFFEF4444)
                          : Colors.redAccent,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final int badgeCount;
  final Color badgeColor; // ✅ បន្ថែម

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    this.badgeCount = 0,
    this.badgeColor = Colors.redAccent,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14 : 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          widget.primaryColor,
                          widget.primaryColor.withOpacity(0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      isSelected ? widget.item.selectedIcon : widget.item.icon,
                      key: ValueKey(isSelected),
                      size: 20,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                  // ✅ Badge with Animation
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: widget.badgeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.badgeColor.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.badgeCount > 99
                                ? '99+'
                                : '${widget.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                color: isSelected ? widget.primaryColor : Colors.grey.shade600,
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(widget.item.label),
            ),
          ],
        ),
      ),
    );
  }
}
