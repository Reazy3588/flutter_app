class CartItem {
  final int id;
  final String name;
  final String slug;
  final String? image;
  final String categoryName;
  final double price;
  int quantity;
  final int stock;
  final double totalPrice;
  final int? variantId; // ✅ បន្ថែម
  final Map<String, dynamic>? variantOptions; // ✅ បន្ថែម

  CartItem({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
    required this.categoryName,
    required this.price,
    required this.quantity,
    required this.stock,
    required this.totalPrice,
    this.variantId,
    this.variantOptions,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'],
        name: json['name'],
        slug: json['slug'] ?? '',
        image: json['image'],
        categoryName: json['category_name'] ?? '',
        price: double.parse(json['price'].toString()),
        quantity: json['quantity'],
        stock: json['stock'],
        totalPrice: double.parse(json['total_price'].toString()),
        variantId: json['variant_id'], // ✅
        variantOptions: json['variant_options'] != null
            ? Map<String, dynamic>.from(json['variant_options'])
            : null, // ✅
      );
}

class Cart {
  final List<CartItem> items;
  final double subtotal;
  final double shipping;
  final double tax;
  final double grandTotal;
  final int count;

  Cart({
    required this.items,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.grandTotal,
    required this.count,
  });

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        items:
            (json['items'] as List).map((e) => CartItem.fromJson(e)).toList(),
        subtotal: double.parse(json['subtotal'].toString()),
        shipping: double.parse(json['shipping'].toString()),
        tax: double.parse(json['tax'].toString()),
        grandTotal: double.parse(json['grand_total'].toString()),
        count: json['count'],
      );
}
