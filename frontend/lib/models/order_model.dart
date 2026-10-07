class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String fullName;
  final String phone;
  final String address;
  final String city;
  final String subtotal;
  final String shipping;
  final String tax;
  final String grandTotal;
  final bool canCancel;
  final String discountAmount;
  final String? statusUpdatedAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.city,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.grandTotal,
    this.canCancel = false,
    required this.discountAmount,
    this.statusUpdatedAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: json['id'],
        orderNumber: json['order_number'] ?? '',
        status: json['status'] ?? 'pending',
        paymentMethod: json['payment_method'] ?? 'cod',
        fullName: json['full_name'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        subtotal: json['subtotal']?.toString() ?? '0',
        shipping: json['shipping']?.toString() ?? '0',
        tax: json['tax']?.toString() ?? '0',
        grandTotal: json['grand_total']?.toString() ?? '0',
        canCancel: json['can_cancel'] ?? false,
        items: (json['items'] as List? ?? [])
            .map((e) => OrderItemModel.fromJson(e))
            .toList(),
        discountAmount: json['discount_amount']?.toString() ?? '0',
        statusUpdatedAt: json['status_updated_at'],
      );
}

class OrderItemModel {
  final int id;
  final String name;
  final String? image;
  final int quantity;
  final String price;
  final Map<String, dynamic>? variantOptions; // ✅ បន្ថែមនៅទីនេះ

  OrderItemModel({
    required this.id,
    required this.name,
    this.image,
    required this.quantity,
    required this.price,
    this.variantOptions, // ✅ បន្ថែមនៅទីនេះ
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: json['id'],
        name: json['name'] ?? '',
        image: json['image'],
        quantity: json['quantity'] ?? 1,
        price: json['price']?.toString() ?? '0',
        variantOptions: json['variant_options'] != null
            ? Map<String, dynamic>.from(json['variant_options'])
            : null, // ✅ បន្ថែមនៅទីនេះ
      );
}
