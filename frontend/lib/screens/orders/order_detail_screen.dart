import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import 'order_tracking_screen.dart';
import 'order_chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  const OrderDetailScreen({super.key, required this.orderNumber});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _dio = ApiService().dio;
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  static const Color _primaryColor = Color(0xFF1F6FEB);
  static const Color _darkColor = Color(0xFF0F172A);
  static const Color _bgColor = Color(0xFFF0F4F8);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _dangerColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final res = await _dio.get('/products/orders/${widget.orderNumber}/');
      if (!mounted) return;
      setState(() {
        _order = res.data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  // ==================== STATUS CONFIG ====================
  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': 'PENDING',
          'icon': Icons.schedule,
          'color': _warningColor,
          'gradient': [_warningColor, const Color(0xFFD97706)],
        };
      case 'confirmed':
        return {
          'label': 'CONFIRMED',
          'icon': Icons.check_circle,
          'color': const Color(0xFF3B82F6),
          'gradient': [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        };
      case 'shipped':
        return {
          'label': 'IN TRANSIT',
          'icon': Icons.local_shipping,
          'color': const Color(0xFF8B5CF6),
          'gradient': [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
        };
      case 'delivered':
        return {
          'label': 'DELIVERED',
          'icon': Icons.check_circle,
          'color': _successColor,
          'gradient': [_successColor, const Color(0xFF059669)],
        };
      case 'cancelled':
        return {
          'label': 'CANCELLED',
          'icon': Icons.cancel,
          'color': _dangerColor,
          'gradient': [_dangerColor, const Color(0xFFDC2626)],
        };
      default:
        return {
          'label': status.toUpperCase(),
          'icon': Icons.help,
          'color': Colors.grey,
          'gradient': [Colors.grey, Colors.grey.shade700],
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _darkColor,
          elevation: 0,
          title: Text(widget.orderNumber),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: _dangerColor),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadOrder();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final status = order['status'] ?? 'pending';
    final config = _getStatusConfig(status);
    final statusColor = config['color'] as Color;
    final statusGradient = config['gradient'] as List<Color>;
    final statusIcon = config['icon'] as IconData;
    final statusLabel = config['label'] as String;

    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        slivers: [
          // ==================== HERO SLIVER APP BAR ====================
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: statusGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative Circles
                    Positioned(
                      top: -60,
                      right: -60,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -100,
                      left: -80,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    statusIcon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Order Details',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.orderNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(order['created_at']),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==================== CONTENT ====================
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Tracking Progress
                if (status != 'cancelled') ...[
                  _buildTrackingCard(status),
                  const SizedBox(height: 16),
                ],

                // Items Card
                _buildItemsCard(order),
                const SizedBox(height: 16),

                // ✅ Delivery Person Card
                if (order['delivery_person'] != null) ...[
                  _buildDeliveryPersonCard(order['delivery_person']),
                  const SizedBox(height: 16),
                ],

                // Customer Info Card
                _buildCustomerCard(order),

                // Payment Summary
                _buildPaymentCard(order),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),

      // ==================== BOTTOM ACTION BAR ====================
      bottomNavigationBar: _buildBottomBar(status),
    );
  }

  // ==================== TRACKING CARD ====================
  Widget _buildTrackingCard(String status) {
    final steps = [
      {'label': 'Pending', 'icon': Icons.schedule},
      {'label': 'Confirmed', 'icon': Icons.check_circle},
      {'label': 'Transit', 'icon': Icons.local_shipping},
      {'label': 'Delivered', 'icon': Icons.home},
    ];

    int currentStep = 0;
    switch (status) {
      case 'pending':
        currentStep = 0;
        break;
      case 'confirmed':
        currentStep = 1;
        break;
      case 'shipped':
        currentStep = 2;
        break;
      case 'delivered':
        currentStep = 3;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.15),
                      _primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress Steps
          Row(
            children: List.generate(steps.length, (i) {
              final done = i <= currentStep;
              final isCurrent = i == currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isCurrent && status != 'delivered')
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: done
                                    ? const LinearGradient(
                                        colors: [
                                          _primaryColor,
                                          _successColor,
                                        ],
                                      )
                                    : null,
                                color: done ? null : Colors.grey.shade200,
                                shape: BoxShape.circle,
                                boxShadow: done
                                    ? [
                                        BoxShadow(
                                          color: _primaryColor.withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                steps[i]['icon'] as IconData,
                                size: 20,
                                color:
                                    done ? Colors.white : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          steps[i]['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                done ? FontWeight.bold : FontWeight.normal,
                            color: done ? _darkColor : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i < currentStep
                                  ? _primaryColor
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==================== ITEMS CARD ====================
  Widget _buildItemsCard(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              Icons.shopping_bag_outlined, 'Items (${items.length})'),
          const SizedBox(height: 20),
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final name = item['name'] ?? 'Product';
    final quantity = item['quantity'] ?? 1;
    final price = item['price'] ?? '0';
    final image = item['image'];
    final variantOptions = item['variant_options'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image != null
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _darkColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: $quantity',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (variantOptions != null &&
                    variantOptions is Map &&
                    variantOptions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    variantOptions.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' • '),
                    style: TextStyle(
                      fontSize: 11,
                      color: _primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Price
          Text(
            '\$$price',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CUSTOMER CARD ====================
  Widget _buildCustomerCard(Map<String, dynamic> order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.location_on_outlined, 'Shipping Address'),
          const SizedBox(height: 20),
          _infoRow(
            Icons.person_outline,
            'Name',
            order['full_name'] ?? '—',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.phone_outlined,
            'Phone',
            order['phone'] ?? '—',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.home_outlined,
            'Address',
            '${order['address'] ?? ''}, ${order['city'] ?? ''}',
          ),
        ],
      ),
    );
  }

  // ==================== PAYMENT CARD ====================
  Widget _buildPaymentCard(Map<String, dynamic> order) {
    final subtotal = order['subtotal'] ?? '0';
    final shipping = order['shipping'] ?? '0';
    final tax = order['tax'] ?? '0';
    final discount = order['discount_amount'] ?? '0';
    final grandTotal = order['grand_total'] ?? '0';
    final paymentMethod = order['payment_method'] ?? 'cod';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.08),
            _primaryColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  paymentMethod.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _summaryRow('Subtotal', subtotal),
          const SizedBox(height: 10),
          _summaryRow('Shipping', shipping),
          const SizedBox(height: 10),
          _summaryRow('Tax', tax),
          if (double.tryParse(discount.toString()) != 0) ...[
            const SizedBox(height: 10),
            _summaryRow('Discount', '-$discount', isDiscount: true),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: _primaryColor.withOpacity(0.15)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              Text(
                '\$$grandTotal',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM BAR ====================
  Widget? _buildBottomBar(String status) {
    if (status == 'delivered' || status == 'cancelled') {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // ✅ Chat Button (ដំណើរការហើយ)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: _primaryColor, width: 1.5),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderChatScreen(
                        orderNumber: widget.orderNumber,
                        orderType: 'customer',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text(
                  'Chat',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Track Button
            if (status == 'shipped' || status == 'confirmed')
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _successColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(
                          orderNumber: widget.orderNumber,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Track Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withOpacity(0.15),
                _primaryColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkColor,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: _primaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: _darkColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, dynamic value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          isDiscount ? '$value' : '\$$value',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDiscount ? _successColor : _darkColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ==================== DELIVERY PERSON CARD ====================
Widget _buildDeliveryPersonCard(Map<String, dynamic> deliveryPerson) {
  final name = deliveryPerson['name'] ?? 'Delivery Person';
  final phone = deliveryPerson['phone'] ?? '';

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF10B981).withOpacity(0.08),
          const Color(0xFF059669).withOpacity(0.03),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: const Color(0xFF10B981).withOpacity(0.2),
        width: 1.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_motorsports_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Your Delivery Person',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '4.9 • Motorbike',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Call Button
              GestureDetector(
                onTap: () {
                  // TODO: Call phone
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phone,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
