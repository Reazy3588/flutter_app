import 'package:flutter/material.dart';

class HomeSearchBar extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback? onCameraTap;
  final VoidCallback onCartTap;
  final int cartItemCount;

  const HomeSearchBar({
    super.key,
    required this.onSearchTap,
    this.onCameraTap,
    required this.onCartTap,
    this.cartItemCount = 0,
  });

  static const _shadow = [
    BoxShadow(
      color: Color(0x0F101828),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _shadow,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Search products...",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircleIconButton(
          icon: Icons.shopping_bag_outlined,
          onTap: onCartTap,
          badgeCount: cartItemCount,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _CircleIconButton(
      {required this.icon, required this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: HomeSearchBar._shadow,
            ),
            child: Icon(icon, color: Colors.black87, size: 21),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                child: Text(
                  '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
