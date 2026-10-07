import 'package:flutter/material.dart';

class CategoryItem {
  final String label;
  final IconData icon;
  final String? image;
  final String? slug;

  const CategoryItem({
    required this.label,
    required this.icon,
    this.image,
    this.slug,
  });
}

class CategoryIconGrid extends StatelessWidget {
  final List<CategoryItem> items;
  final ValueChanged<CategoryItem> onTap;
  final int maxVisible;

  const CategoryIconGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.maxVisible = 6,
  });

  static const List<Color> _palette = [
    Color(0xFF4C6FFF),
    Color(0xFFFF8A65),
    Color(0xFF26C6DA),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
    Color(0xFFFFB300),
  ];

  @override
  Widget build(BuildContext context) {
    final showMoreTile = items.length > maxVisible;
    final visibleItems = showMoreTile ? items.take(maxVisible).toList() : items;

    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: visibleItems.length + (showMoreTile ? 1 : 0),
        itemBuilder: (context, index) {
          if (showMoreTile && index == visibleItems.length) {
            return _buildTile(
              context,
              icon: Icons.more_horiz,
              label: "More",
              color: Colors.grey.shade400,
              onTap: () => _openAllCategoriesSheet(context),
            );
          }
          final item = visibleItems[index];
          final color = _palette[index % _palette.length];
          return _buildTile(
            context,
            icon: item.icon,
            label: item.label,
            color: color,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                // ✅ បង្ហាញ Icon ជានិច្ច
                child: Icon(icon, size: 23, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAllCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _AllCategoriesSheet(
        items: items,
        onSelect: (item) {
          Navigator.of(sheetContext).pop();
          onTap(item);
        },
      ),
    );
  }
}

class _AllCategoriesSheet extends StatelessWidget {
  final List<CategoryItem> items;
  final ValueChanged<CategoryItem> onSelect;

  const _AllCategoriesSheet({required this.items, required this.onSelect});

  static const List<Color> _palette = CategoryIconGrid._palette;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(
                "All Categories",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final color = _palette[index % _palette.length];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelect(item),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: color.withOpacity(0.2), width: 2),
                            ),
                            // ✅ បង្ហាញ Icon ជានិច្ច
                            child: Icon(item.icon, size: 24, color: color),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
