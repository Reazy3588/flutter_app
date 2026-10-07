import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/admin_order_model.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';

/// Staff-only Delivery Dashboard.
///
/// Simplified, deliberately 2-click flow (per product decision):
///   1. "Confirm Order"   — pending  -> shipped   (skips a separate
///      "confirmed" click; the order instantly shows as Shipped to
///      the customer's tracking screen)
///   2. "Confirm Arrived" — shipped  -> delivered (only enabled once
///      [_minWaitMinutes] have passed since step 1, simulating real
///      delivery time instead of an instant click)
/// "Cancel" is available on Pending and Shipped orders at any time.
class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

const _tabs = ['pending', 'shipped', 'delivered'];
const _tabLabels = {
  'pending': 'Pending',
  'shipped': 'Shipped',
  'delivered': 'Delivered',
};
const Color primary = Color(0xFF1F6FEB);
const int minWaitMinutes = 5; // must match backend DELIVERY_MIN_WAIT_MINUTES

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Delivery Dashboard"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((s) => Tab(text: _tabLabels[s])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((s) => _StatusTab(status: s)).toList(),
      ),
    );
  }
}

class _StatusTab extends StatefulWidget {
  final String status;
  const _StatusTab({required this.status});

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab>
    with AutomaticKeepAliveClientMixin {
  final _service = OrderService();
  List<AdminOrderModel> _orders = [];
  bool _loading = true;
  String? _error;
  String? _updatingOrderNumber;
  Timer? _tickTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    // Only the "shipped" tab needs a live-ticking countdown.
    if (widget.status == 'shipped') {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {}); // just repaints the countdown text
      });
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _service.getAdminOrders(status: widget.status);
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  Duration _remaining(AdminOrderModel order) {
    final elapsed = DateTime.now().difference(order.updatedAt);
    final remaining = const Duration(minutes: minWaitMinutes) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _setStatus(AdminOrderModel order, String newStatus) async {
    setState(() => _updatingOrderNumber = order.orderNumber);
    try {
      await _service.updateOrderStatus(order.orderNumber, newStatus);
      if (!mounted) return;
      setState(
          () => _orders.removeWhere((o) => o.orderNumber == order.orderNumber));
      final label = newStatus == 'shipped'
          ? "confirmed"
          : newStatus == 'delivered'
              ? "delivered"
              : "cancelled";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${order.orderNumber} $label"),
        backgroundColor: newStatus == 'cancelled' ? Colors.red : Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(extractErrorMessage(e)),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _updatingOrderNumber = null);
    }
  }

  Future<void> _confirmCancel(AdminOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cancel Order"),
        content:
            Text("Cancel order ${order.orderNumber}? Stock will be restored."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
    if (confirm == true) _setStatus(order, 'cancelled');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(
              child:
                  Text(_error!, style: TextStyle(color: Colors.grey.shade600))),
          const SizedBox(height: 16),
          Center(
              child:
                  OutlinedButton(onPressed: _load, child: const Text("Retry"))),
        ],
      );
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Icon(Icons.inventory_2_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Center(
              child: Text(
                  "No ${_tabLabels[widget.status]!.toLowerCase()} orders",
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          final updating = _updatingOrderNumber == order.orderNumber;
          final remaining =
              widget.status == 'shipped' ? _remaining(order) : Duration.zero;
          final canDeliver =
              widget.status == 'shipped' && remaining == Duration.zero;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(order.orderNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("\$${order.grandTotal}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(order.customerName,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    const Icon(Icons.phone_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(order.customerPhone,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(order.city,
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    "${order.itemCount} item(s) · ${order.paymentMethod.toUpperCase()}",
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),

                // Live countdown while waiting out the delivery window
                if (widget.status == 'shipped') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: canDeliver
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            canDeliver
                                ? Icons.check_circle
                                : Icons.timer_outlined,
                            size: 15,
                            color: canDeliver ? Colors.green : Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          canDeliver
                              ? "Ready to confirm arrival"
                              : "Arriving in ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: canDeliver
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.status == 'pending')
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: updating
                                ? null
                                : () => _setStatus(order, 'shipped'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: updating
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text("Confirm Order",
                                    style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    if (widget.status == 'shipped')
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: (updating || !canDeliver)
                                ? null
                                : () => _setStatus(order, 'delivered'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canDeliver
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: updating
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text("Confirm Arrived",
                                    style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    if (widget.status != 'delivered') ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed:
                              updating ? null : () => _confirmCancel(order),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
