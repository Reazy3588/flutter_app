class DeliveryOrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String customerName;
  final String customerPhone;
  final String address;
  final String city;
  final double grandTotal;
  final String paymentMethod;
  final int itemCount;
  final List<DeliveryItemModel> items;
  final double? deliveryLat;
  final double? deliveryLng;
  final DateTime? deliveryUpdatedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime? statusUpdatedAt;

  DeliveryOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.city,
    required this.grandTotal,
    required this.paymentMethod,
    required this.itemCount,
    required this.items,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryUpdatedAt,
    this.deliveredAt,
    required this.createdAt,
    this.statusUpdatedAt,
  });

  factory DeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    try {
      return DeliveryOrderModel(
        id: json['id'] ?? 0,
        orderNumber: json['order_number'] ?? '',
        status: json['status'] ?? 'pending',
        customerName: json['customer_name'] ?? json['full_name'] ?? '',
        customerPhone: json['customer_phone'] ?? json['phone'] ?? '',
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        grandTotal:
            double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0,
        paymentMethod: json['payment_method'] ?? 'cod',
        itemCount: json['item_count'] ?? 0,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => DeliveryItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        deliveryLat: json['delivery_lat'] != null
            ? double.tryParse(json['delivery_lat'].toString())
            : null,
        deliveryLng: json['delivery_lng'] != null
            ? double.tryParse(json['delivery_lng'].toString())
            : null,
        deliveryUpdatedAt: json['delivery_updated_at'] != null
            ? DateTime.tryParse(json['delivery_updated_at'].toString())
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.tryParse(json['delivered_at'].toString())
            : null,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        statusUpdatedAt: json['status_updated_at'] != null
            ? DateTime.tryParse(json['status_updated_at'].toString())
            : null,
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing DeliveryOrderModel: $e');
      print('❌ JSON Data: $json');
      print('❌ StackTrace: $stackTrace');
      rethrow;
    }
  }
}

class DeliveryItemModel {
  final int id;
  final String productName;
  final int quantity;
  final double price;
  final Map<String, dynamic> variantOptions;

  DeliveryItemModel({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.variantOptions,
  });

  factory DeliveryItemModel.fromJson(Map<String, dynamic> json) {
    return DeliveryItemModel(
      id: json['id'] ?? 0,
      productName:
          json['name'] ?? json['product_name'] ?? 'Unknown', // ✅ បន្ថែម 'name'
      quantity: json['quantity'] ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      variantOptions: json['variant_options'] ?? {},
    );
  }
}
