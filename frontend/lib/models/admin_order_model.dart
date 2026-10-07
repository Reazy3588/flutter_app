class AdminOrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String customerName;
  final String customerPhone;
  final String city;
  final String grandTotal;
  final int itemCount;
  final String createdAt;
  final DateTime updatedAt;

  AdminOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.customerName,
    required this.customerPhone,
    required this.city,
    required this.grandTotal,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminOrderModel.fromJson(Map<String, dynamic> json) =>
      AdminOrderModel(
        id: json['id'],
        orderNumber: json['order_number'] ?? '',
        status: json['status'] ?? 'pending',
        paymentMethod: json['payment_method'] ?? 'cod',
        customerName: json['customer_name'] ?? '',
        customerPhone: json['customer_phone'] ?? '',
        city: json['city'] ?? '',
        grandTotal: json['grand_total']?.toString() ?? '0',
        itemCount: json['item_count'] ?? 0,
        createdAt: json['created_at'] ?? '',
        updatedAt: DateTime.tryParse(json['updated_at'] ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
