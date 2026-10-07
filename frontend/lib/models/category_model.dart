class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? image;
  final int productCount;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
    required this.productCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      image: json['image'],
      productCount: json['product_count'] ?? 0,
    );
  }
}
