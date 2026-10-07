import 'package:flutter/material.dart';
import 'category_icon_grid.dart';

/// Horizontal scrollable icon strip used on the Browse page — minimal
/// style matching the reference design: no box/border/background at
/// all, just icon + label that switches to the accent color when
/// selected. Clean and compact, so many categories fit on screen.
class CategoryIconStrip extends StatelessWidget {
  final List<CategoryItem> items;
  final String? selectedSlug;
  final ValueChanged<CategoryItem> onTap;

  const CategoryIconStrip({
    super.key,
    required this.items,
    required this.selectedSlug,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return SizedBox(
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.slug == selectedSlug;
          final color = selected ? primary : Colors.grey.shade700;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => onTap(item),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? primary.withOpacity(0.12)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.icon, size: 24, color: color),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 68,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
