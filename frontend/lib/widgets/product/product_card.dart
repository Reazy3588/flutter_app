import 'package:flutter/material.dart';
import '../../models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onWishlistTap;
  final VoidCallback? onAddTap;
  final bool isWishlisted;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onWishlistTap,
    this.onAddTap,
    this.isWishlisted = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Card តូច (៤ ជួរឈរ) → ប្រើទំហំតូចជាង
      final bool compact = constraints.maxWidth < 120;
      return _buildCard(context, compact);
    });
  }

  Widget _buildCard(BuildContext context, bool compact) {
    final primary = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D101828),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.all(compact ? 4 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Image (inset, rounded) =====
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 10 : 14),
                child: _buildImageArea(compact),
              ),
            ),

            // ===== Info =====
            Padding(
              padding: EdgeInsets.fromLTRB(
                  compact ? 3 : 4, compact ? 5 : 7, compact ? 3 : 4, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 10.5 : 12,
                      color: const Color(0xFF111827),
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 3),

                  // Rating + sold
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: compact ? 11 : 13, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: compact ? 9 : 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          "· ${product.soldCount} sold",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 8.5 : 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 3 : 5),

                  // Price + Add button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.hasDiscount)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "\$${product.price.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: compact ? 9 : 10.5,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "\$${product.finalPrice.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 12 : 14,
                                  color: product.hasDiscount
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF111827),
                                  letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? 3 : 6),
                      _AddButton(
                        size: compact ? 26 : 32,
                        enabled: product.inStock,
                        color: primary,
                        onTap: onAddTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(bool compact) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 247, 247, 247)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: EdgeInsets.all(compact ? 4 : 8),
          child: product.image != null && product.image!.isNotEmpty
              ? Image.network(
                  product.image!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_outlined,
                        size: 22, color: Colors.grey),
                  ),
                )
              : const Center(
                  child:
                      Icon(Icons.image_outlined, size: 22, color: Colors.grey),
                ),
        ),

        // Badges (NEW + Discount)
        Positioned(
          top: 4,
          left: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.isNewArrival)
                _Badge(
                    text: "NEW",
                    color: const Color(0xFF2563EB),
                    compact: compact),
              if (product.isNewArrival && product.hasDiscount)
                const SizedBox(height: 3),
              if (product.hasDiscount)
                _Badge(
                  text: "-${product.discountPercent}%",
                  color: const Color(0xFFE53935),
                  compact: compact,
                ),
            ],
          ),
        ),

        // Wishlist (glass circle)
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onWishlistTap,
            child: Container(
              padding: EdgeInsets.all(compact ? 3 : 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 4),
                ],
              ),
              child: Icon(
                isWishlisted
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: compact ? 12 : 15,
                color: isWishlisted ? Colors.redAccent : Colors.grey.shade600,
              ),
            ),
          ),
        ),

        // Out of stock
        if (!product.inStock)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45),
              alignment: Alignment.center,
              child: Text(
                "OUT OF STOCK",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 8.5 : 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final double size;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _AddButton({
    required this.size,
    required this.enabled,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(size * 0.34),
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.34),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child:
              Icon(Icons.add_rounded, color: Colors.white, size: size * 0.62),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final bool compact;

  const _Badge({required this.text, required this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6, vertical: compact ? 1.5 : 2.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(compact ? 5 : 7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 7.5 : 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
