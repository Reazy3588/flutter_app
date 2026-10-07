import 'package:flutter/material.dart';

/// Maps a Category name coming from the backend (e.g. "Shoes", "Bags")
/// to a sensible icon. Centralized here so Home, Browse, and any future
/// screen all pick the same icon for the same category — one place to
/// tweak if you add new category types.
IconData iconForCategoryName(String name) {
  final n = name.toLowerCase();
  if (n.contains('camera') || n.contains('photo'))
    return Icons.camera_alt_outlined;
  if (n.contains('power bank') ||
      n.contains('battery') ||
      n.contains('charger')) return Icons.battery_charging_full_outlined;
  if (n.contains('headphone') || n.contains('earbud') || n.contains('audio'))
    return Icons.headphones_outlined;
  if (n.contains('laptop') || n.contains('computer') || n.contains('pc'))
    return Icons.laptop_mac_outlined;
  if (n.contains('watch')) return Icons.watch_outlined;
  if (n.contains('bag')) return Icons.shopping_bag_outlined;
  if (n.contains('beauty') || n.contains('cosmetic'))
    return Icons.auto_awesome_outlined;
  if (n.contains('cloth') || n.contains('fashion') || n.contains('wear'))
    return Icons.checkroom_outlined;
  if (n.contains('accessor') || n.contains('glass'))
    return Icons.watch_later_outlined;
  if (n.contains('shoe') || n.contains('sneaker')) return Icons.directions_walk;
  if (n.contains('lifestyle')) return Icons.spa_outlined;
  if (n.contains('phone') || n.contains('tablet') || n.contains('electronic'))
    return Icons.phone_iphone;
  if (n.contains('food') || n.contains('grocery'))
    return Icons.fastfood_outlined;
  if (n.contains('home') || n.contains('furniture'))
    return Icons.chair_outlined;
  if (n.contains('book')) return Icons.menu_book_outlined;
  if (n.contains('toy')) return Icons.toys_outlined;
  return Icons.category_outlined;
}
