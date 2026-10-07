import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<ProductModel> products;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ValueChanged<ProductModel>? onProductTap;
  final ValueChanged<ProductModel>? onWishlistTap;
  final ValueChanged<ProductModel>? onAddTap;
  final Set<int> wishlistedIds;

  /// ✅ ចំនួនជួរឈរ (Columns) ដែលចង់បង្ហាញ
  /// ឧ. ៤ សម្រាប់ ៤ ជួរឈរ
  final int crossAxisCount;

  /// ✅ សមាមាត្រ ទទឹង/កម្ពស់ របស់ Card នីមួយៗ
  /// តម្លៃតូច → Card ខ្ពស់ជាងទទឹង
  final double childAspectRatio;

  const ProductGrid({
    super.key,
    required this.products,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.onProductTap,
    this.onWishlistTap,
    this.onAddTap,
    this.wishlistedIds = const {},
    this.crossAxisCount = 4, // ✅ Default ជា ៤ ជួរឈរ
    this.childAspectRatio = 0.5, // ✅ សម្រាប់ ៤ ជួរឈរ
  });

  Widget _buildCard(ProductModel product) {
    return ProductCard(
      product: product,
      onTap: onProductTap != null ? () => onProductTap!(product) : null,
      onWishlistTap:
          onWishlistTap != null ? () => onWishlistTap!(product) : null,
      onAddTap: onAddTap != null ? () => onAddTap!(product) : null,
      isWishlisted: wishlistedIds.contains(product.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: EdgeInsets.zero,
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: crossAxisCount >= 4 ? 6 : 8,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) => _buildCard(products[index]),
    );
  }
}
