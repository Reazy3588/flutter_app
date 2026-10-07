import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';

class ReceiptScreen extends StatefulWidget {
  final String orderNumber;
  final String paymentMethod;

  const ReceiptScreen({
    super.key,
    required this.orderNumber,
    required this.paymentMethod,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _orderService = OrderService();

  OrderModel? _order;
  bool _loading = true;
  String? _error;

  // ===== NEW PALETTE =====
  static const Color primary =
      Color(0xFF4F46E5); // indigo, feels more premium than plain blue
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color bg = Color(0xFFF4F5F9);
  static const Color ink = Color(0xFF1E1B2E);
  static const Color muted = Color(0xFF8B8D98);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await _orderService.getOrderDetail(widget.orderNumber);
      if (!mounted) return;
      setState(() {
        _order = order;
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

  String _paymentMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'aba':
        return 'ABA PayWay';
      case 'acleda':
        return 'ACLEDA Bank';
      case 'bakong':
        return 'Bakong (KHQR)';
      default:
        return method.toUpperCase();
    }
  }

  IconData _paymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return Icons.local_shipping_outlined;
      case 'aba':
      case 'acleda':
        return Icons.account_balance_outlined;
      case 'bakong':
        return Icons.qr_code_2_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  String _money(String value) {
    final double amount = double.tryParse(value) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
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
      final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day} ${months[date.month - 1]} ${date.year} · '
          '$h:${date.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return '—';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return success;
      case 'cancelled':
        return danger;
      default:
        return warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: ink,
          elevation: 0,
          title: const Text('Receipt'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: danger),
              const SizedBox(height: 16),
              Text(_error ?? 'Order not found',
                  style: const TextStyle(color: muted)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadOrder,
                style: FilledButton.styleFrom(backgroundColor: primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order!;
    final statusColor = _statusColor(order.status);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ===== TOP APP BAR =====
          SliverAppBar(
            pinned: true,
            backgroundColor: bg,
            surfaceTintColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: ink),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text(
              'Receipt',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share, size: 20, color: ink),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon')),
                  );
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ===== SUCCESS HERO =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: success.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: success, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Payment Successful',
                        style: TextStyle(
                          color: ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(order.grandTotal),
                        style: const TextStyle(
                          color: primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== MAIN CARD =====
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withOpacity(0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Order number + status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ORDER NUMBER',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                      letterSpacing: 0.6,
                                    )),
                                const SizedBox(height: 3),
                                Text(
                                  '#${order.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    order.status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(height: 1, color: Color(0xFFEEEFF3)),
                        ),

                        // Date + payment, as two chips
                        Row(
                          children: [
                            Expanded(
                              child: _MetaTile(
                                icon: Icons.schedule,
                                label: 'Date',
                                value: _formatDate(order.statusUpdatedAt),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MetaTile(
                                icon: _paymentMethodIcon(order.paymentMethod),
                                label: 'Payment',
                                value: _paymentMethodLabel(order.paymentMethod),
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(height: 1, color: Color(0xFFEEEFF3)),
                        ),

                        // Bill to
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_outline,
                                  color: primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.fullName,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.phone,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${order.address}, ${order.city}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(height: 1, color: Color(0xFFEEEFF3)),
                        ),

                        // Items
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ITEMS (${order.items.length})',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: muted,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...order.items.map((item) {
                          final price = double.tryParse(item.price) ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: ink,
                                        ),
                                      ),
                                      if (item.variantOptions != null &&
                                          item.variantOptions!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            item.variantOptions!.entries
                                                .map((e) =>
                                                    '${e.key}: ${e.value}')
                                                .join(' · '),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _money(price.toStringAsFixed(2)),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1, color: Color(0xFFEEEFF3)),
                        ),

                        // Totals
                        _buildTotalRow('Subtotal', order.subtotal),
                        _buildTotalRow('Shipping', order.shipping),
                        _buildTotalRow('Tax', order.tax),
                        if (double.tryParse(order.discountAmount) != null &&
                            double.parse(order.discountAmount) > 0)
                          _buildTotalRow(
                            'Discount',
                            '-${order.discountAmount}',
                            isDiscount: true,
                          ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primary, primaryDark],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Paid',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _money(order.grandTotal),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ===== SHOP INFO STRIP (moved out of the card, lighter weight) =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_outlined,
                            color: primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Admin Shop',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Phnom Penh, Cambodia · +855 12 345 678',
                              style: TextStyle(fontSize: 11.5, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ===== ACTION BUTTONS =====
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download PDF coming soon'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: const BorderSide(color: Color(0xFFE0E1F5)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                        icon: const Icon(Icons.home_outlined, size: 18),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Questions? support@shop.com',
                    style: TextStyle(fontSize: 11.5, color: muted),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDiscount ? success : ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== small meta chip used for date/payment =====
class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF8B8D98))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1B2E),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
