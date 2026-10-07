class ProductModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final double price;
  final double? discountPrice;
  final double finalPrice;
  final int discountPercent;
  final String? image;
  final String categoryName;
  final bool inStock;
  final int stock;
  final List<String> galleryImages;
  final bool isNewArrival;
  final bool isBestSeller;
  final bool isRecommended;
  final double rating;
  final int soldCount;
  final List<ProductOption> options;
  final List<ProductVariant> variants;

  ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.price,
    this.discountPrice,
    required this.finalPrice,
    required this.discountPercent,
    this.image,
    required this.categoryName,
    required this.inStock,
    this.stock = 0,
    this.galleryImages = const [],
    required this.isNewArrival,
    required this.isBestSeller,
    required this.isRecommended,
    required this.rating,
    required this.soldCount,
    this.options = const [],
    this.variants = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      price: double.tryParse(json['price'].toString()) ?? 0,
      discountPrice: json['discount_price'] != null
          ? double.tryParse(json['discount_price'].toString())
          : null,
      finalPrice: double.tryParse(json['final_price'].toString()) ?? 0,
      discountPercent: json['discount_percent'] ?? 0,
      image: json['image'],
      categoryName: json['category_name'] ?? (json['category']?['name'] ?? ''),
      inStock: json['in_stock'] ?? false,
      stock: json['stock'] ?? 0,
      galleryImages: json['gallery_images'] != null
          ? (json['gallery_images'] as List)
              .map((e) =>
                  e is Map ? (e['image']?.toString() ?? '') : e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
      isNewArrival: json['is_new_arrival'] ?? false,
      isBestSeller: json['is_best_seller'] ?? false,
      isRecommended: json['is_recommended'] ?? false,
      rating: double.tryParse(json['rating'].toString()) ?? 0,
      soldCount: json['sold_count'] ?? 0,
      options: (json['options'] as List? ?? [])
          .map((e) => ProductOption.fromJson(e))
          .toList(),
      variants: (json['variants'] as List? ?? [])
          .map((e) => ProductVariant.fromJson(e))
          .toList(),
    );
  }

  bool get hasDiscount => discountPrice != null && discountPrice! < price;
}

// ===================== PRODUCT OPTIONS =====================

class ProductOption {
  final int id;
  final String name;
  final int position;
  final List<ProductOptionValue> values;

  ProductOption({
    required this.id,
    required this.name,
    required this.position,
    required this.values,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) => ProductOption(
        id: json['id'],
        name: json['name'] ?? '',
        position: json['position'] ?? 0,
        values: (json['values'] as List? ?? [])
            .map((e) => ProductOptionValue.fromJson(e))
            .toList(),
      );
}

class ProductOptionValue {
  final int id;
  final String value;
  final int position;

  ProductOptionValue({
    required this.id,
    required this.value,
    required this.position,
  });

  factory ProductOptionValue.fromJson(Map<String, dynamic> json) =>
      ProductOptionValue(
        id: json['id'],
        value: json['value'] ?? '',
        position: json['position'] ?? 0,
      );
}

// ===================== PRODUCT VARIANTS =====================

class ProductVariant {
  final int id;
  final Map<String, dynamic> options;
  final Map<String, dynamic>? displayOptions;
  final int stock;
  final double? price;
  final double finalPrice;
  final String sku;
  final String? image;
  final String? imageUrl;
  final bool inStock;
  final bool isActive;

  ProductVariant({
    required this.id,
    required this.options,
    this.displayOptions,
    required this.stock,
    this.price,
    required this.finalPrice,
    required this.sku,
    this.image,
    this.imageUrl,
    required this.inStock,
    required this.isActive,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'],
        options: Map<String, dynamic>.from(json['options'] ?? {}),
        displayOptions: json['display_options'] != null
            ? Map<String, dynamic>.from(json['display_options'])
            : null,
        stock: json['stock'] ?? 0,
        price: json['price'] != null
            ? double.tryParse(json['price'].toString())
            : null,
        finalPrice: double.tryParse(json['final_price'].toString()) ?? 0,
        sku: json['sku'] ?? '',
        image: json['image'],
        imageUrl: json['image_url'],
        inStock: json['in_stock'] ?? false,
        isActive: json['is_active'] ?? true,
      );
}
