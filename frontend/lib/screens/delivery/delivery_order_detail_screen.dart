import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/delivery_order_model.dart';
import '../../services/delivery_service.dart';
import '../../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import '../orders/order_chat_screen.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final String orderNumber;
  const DeliveryOrderDetailScreen({super.key, required this.orderNumber});

  @override
  State<DeliveryOrderDetailScreen> createState() =>
      _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  final _service = DeliveryService();
  DeliveryOrderModel? _order;
  bool _loading = true;
  bool _updating = false;
  String? _error;

  Timer? _locationTimer;

  static const Color _primaryColor = Color(0xFF1F6FEB);
  static const Color _darkColor = Color(0xFF0F172A);
  static const Color _bgColor = Color(0xFFF7F8FA);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _dangerColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _service.getOrderDetail(widget.orderNumber);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });

      if (order.status == 'shipped') _startLocationTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
        final pos = await Geolocator.getCurrentPosition();
        await _service.updateLocation(
          orderNumber: widget.orderNumber,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (e) {
        debugPrint('Location update failed: $e');
      }
    });
  }

  Future<void> _updateStatus(String newStatus, {String? reason}) async {
    setState(() => _updating = true);
    try {
      final updated = await _service.updateStatus(
        orderNumber: widget.orderNumber,
        status: newStatus,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _order = updated);

      _showSnack('Status updated to ${newStatus.toUpperCase()}', _successColor);
      if (newStatus == 'delivered' || newStatus == 'cancelled') {
        _locationTimer?.cancel();
      }
      if (newStatus == 'shipped') _startLocationTracking();
    } catch (e) {
      _showSnack(extractErrorMessage(e), _dangerColor);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cancel Delivery'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Reason for cancellation...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _dangerColor),
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('cancelled', reason: reasonCtrl.text);
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _error != null
              ? _buildError()
              : _buildBody(),
      bottomNavigationBar: _order != null ? _buildActionButtons() : null,
    );
  }

  // ==================== BODY ====================
  Widget _buildBody() {
    final order = _order!;
    return CustomScrollView(
      slivers: [
        // ... SliverAppBar ដើមរក្សាដើម ...

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ✅ Summary Card (បង្ហាញតែពេល Delivered ឬ Cancelled)
              if (order.status == 'delivered' || order.status == 'cancelled')
                _buildSummaryCard(order),

              _buildStatusCard(order),
              const SizedBox(height: 16),
              _buildCustomerCard(order),
              const SizedBox(height: 16),
              _buildItemsCard(order),
              const SizedBox(height: 16),
              _buildPaymentCard(order),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

// ✅ Summary Card Widget
  Widget _buildSummaryCard(DeliveryOrderModel order) {
    final isDelivered = order.status == 'delivered';
    final color = isDelivered ? _successColor : _dangerColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isDelivered ? Icons.check : Icons.cancel,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDelivered ? 'Order Delivered' : 'Order Cancelled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDelivered
                      ? 'Thanks for completing this delivery'
                      : 'This order was cancelled',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATUS CHIP ====================
  Widget _buildStatusChip() {
    final status = _order!.status;
    Color color;
    String label;

    switch (status) {
      case 'confirmed':
        color = _warningColor;
        label = 'PENDING';
        break;
      case 'shipped':
        color = _primaryColor;
        label = 'IN TRANSIT';
        break;
      case 'delivered':
        color = _successColor;
        label = 'DELIVERED';
        break;
      case 'cancelled':
        color = _dangerColor;
        label = 'CANCELLED';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATUS CARD ====================
  Widget _buildStatusCard(DeliveryOrderModel order) {
    final steps = [
      {'status': 'confirmed', 'label': 'Confirmed', 'icon': Icons.check},
      {
        'status': 'shipped',
        'label': 'In Transit',
        'icon': Icons.local_shipping
      },
      {'status': 'delivered', 'label': 'Delivered', 'icon': Icons.home},
    ];

    int currentStep = 0;
    if (order.status == 'shipped') currentStep = 1;
    if (order.status == 'delivered') currentStep = 2;
    if (order.status == 'cancelled') currentStep = -1;

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
                'Delivery Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (order.status == 'cancelled')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _dangerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _dangerColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: _dangerColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This order has been cancelled',
                      style: TextStyle(
                        color: _dangerColor.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
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
                              // Outer Ring (for current step)
                              if (isCurrent && order.status != 'delivered')
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: done
                                      ? _primaryColor
                                      : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                  boxShadow: done
                                      ? [
                                          BoxShadow(
                                            color:
                                                _primaryColor.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  steps[i]['icon'] as IconData,
                                  size: 22,
                                  color: done
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            steps[i]['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: done ? _darkColor : Colors.grey.shade500,
                              fontWeight:
                                  done ? FontWeight.bold : FontWeight.normal,
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

  // ==================== CUSTOMER CARD ====================
  Widget _buildCustomerCard(DeliveryOrderModel order) {
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
          _sectionHeader(Icons.person, 'Customer Info'),
          const SizedBox(height: 20),
          _infoRow(Icons.person_outline, 'Name', order.customerName),
          const SizedBox(height: 12),
          _infoRow(Icons.phone_outlined, 'Phone', order.customerPhone),
          const SizedBox(height: 12),
          _infoRow(
            Icons.location_on_outlined,
            'Address',
            '${order.address}, ${order.city}',
          ),
        ],
      ),
    );
  }

  // ==================== ITEMS CARD ====================
  Widget _buildItemsCard(DeliveryOrderModel order) {
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
            Icons.shopping_bag_outlined,
            'Items (${order.items.length})',
          ),
          const SizedBox(height: 20),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 22,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _darkColor,
                            ),
                          ),
                          Text(
                            'Quantity: ${item.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ==================== PAYMENT CARD ====================
  Widget _buildPaymentCard(DeliveryOrderModel order) {
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
        border: Border.all(color: _primaryColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.payment,
                      size: 16,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  order.paymentMethod.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _primaryColor.withOpacity(0.15)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total (COD)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              Text(
                '\$${order.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
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

  // ==================== ACTION BUTTONS ====================
  Widget? _buildActionButtons() {
    final order = _order!;

    // ✅ បើ Delivered ឬ Cancelled → មិនបង្ហាញប៊ូតុង
    if (order.status == 'delivered' || order.status == 'cancelled') {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ បន្ថែមប៊ូតុង Chat នៅខាងលើ
            SizedBox(
              width: double.infinity,
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
                        orderType: 'delivery',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text(
                  'Chat with Customer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Action Buttons ដើម
            Row(
              children: [
                // Pending / Confirmed → Cancel + Start
                if (order.status == 'pending' ||
                    order.status == 'confirmed') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _dangerColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: _dangerColor, width: 1.5),
                      ),
                      onPressed: _updating ? null : _showCancelDialog,
                      icon: const Icon(Icons.close,
                          color: _dangerColor, size: 20),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _dangerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          _updating ? null : () => _updateStatus('shipped'),
                      icon: const Icon(Icons.local_shipping,
                          color: Colors.white, size: 20),
                      label: const Text(
                        'Start Delivery',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],

                // Shipped → Failed + Delivered
                if (order.status == 'shipped') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _dangerColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: _dangerColor, width: 1.5),
                      ),
                      onPressed: _updating ? null : _showCancelDialog,
                      icon: const Icon(Icons.close,
                          color: _dangerColor, size: 20),
                      label: const Text(
                        'Failed',
                        style: TextStyle(
                          color: _dangerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _successColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          _updating ? null : () => _updateStatus('delivered'),
                      icon: const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                      label: const Text(
                        'Delivered',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _dangerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 50,
                color: _dangerColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
    );
  }
}
