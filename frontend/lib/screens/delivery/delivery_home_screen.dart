import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/delivery_order_model.dart';
import '../../services/delivery_service.dart';
import '../../services/api_service.dart';
import 'delivery_order_detail_screen.dart';
import 'delivery_profile_screen.dart'; // ✅ បន្ថែម
import '../../services/chat_notification_service.dart';

class DeliveryHomeScreen extends StatefulWidget {
  final UserModel user;
  const DeliveryHomeScreen({super.key, required this.user});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = DeliveryService();

  List<DeliveryOrderModel> _pending = [];
  List<DeliveryOrderModel> _inTransit = [];
  List<DeliveryOrderModel> _completed = [];
  Map<String, dynamic>? _stats, _earnings;

  bool _loading = true;
  String? _error;
  int _currentTab = 0;

  // ✅ ពណ៌ខៀវ (ដូច App Default)
  static const Color _primaryColor = Color(0xFF1F6FEB);
  static const Color _darkColor = Color(0xFF0F172A);
  static const Color _bgColor = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getOrders(status: 'confirmed'),
        _service.getOrders(status: 'shipped'),
        _service.getOrders(status: 'delivered'),
        _service.getStats(),
        _service.getEarnings(), // ✅ បន្ថែមនេះ
      ]);

      if (!mounted) return;
      setState(() {
        _pending = results[0] as List<DeliveryOrderModel>;
        _inTransit = results[1] as List<DeliveryOrderModel>;
        _completed = results[2] as List<DeliveryOrderModel>;
        _stats = results[3] as Map<String, dynamic>;
        _earnings = results[4] as Map<String, dynamic>; // ✅ បន្ថែមនេះ
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: _currentTab == 0
            ? _buildOrdersTab()
            : _currentTab == 1
                ? _buildStatsTab()
                : DeliveryProfileScreen(user: widget.user),
      ),
      // ✅ Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ==================== BOTTOM NAV ====================
  Widget _buildBottomNav() {
  return Container(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedBuilder(
          animation: ChatNotificationService(),
          builder: (context, _) {
            final unread = ChatNotificationService().unreadCount;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  icon: Icons.home_rounded,
                  label: 'Orders',
                  index: 0,
                  badgeCount: unread, // ✅ បន្ថែម
                ),
                _navItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  index: 1,
                ),
                _navItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: 2,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

// ✅ កែ _navItem ឱ្យទទួល badgeCount
Widget _navItem({
  required IconData icon,
  required String label,
  required int index,
  int badgeCount = 0,
}) {
  final isSelected = _currentTab == index;
  return GestureDetector(
    onTap: () => setState(() => _currentTab = index),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected ? _primaryColor : Colors.grey.shade400,
                size: 24,
              ),
              // ✅ Badge
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? _primaryColor : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ),
  );
}

  // ==================== ORDERS TAB ====================
  Widget _buildOrdersTab() {
    return Column(
      children: [
        _buildHeader(),
        _buildStatsBar(),
        _buildTabBar(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryColor))
              : _error != null
                  ? _buildError()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrderList(_pending, 'No pending orders'),
                        _buildOrderList(_inTransit, 'No orders in transit'),
                        _buildOrderList(_completed, 'No completed orders'),
                      ],
                    ),
        ),
      ],
    );
  }

  // ==================== STATS TAB ====================
  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Earnings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Overview of your delivery income',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // ✅ Total Earnings Card (Hero)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryColor, Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Total Earned',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '\$0.50/order',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '\$${_earnings?['total_earned']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_earnings?['total_orders'] ?? 0} deliveries completed',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ✅ Period Breakdown
          const Text(
            'Period Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _earningsPeriodCard(
                  icon: Icons.today,
                  label: 'Today',
                  value:
                      '\$${_earnings?['today']?.toStringAsFixed(2) ?? '0.00'}',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _earningsPeriodCard(
                  icon: Icons.date_range,
                  label: 'This Week',
                  value:
                      '\$${_earnings?['this_week']?.toStringAsFixed(2) ?? '0.00'}',
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _earningsPeriodCard(
                  icon: Icons.calendar_month,
                  label: 'This Month',
                  value:
                      '\$${_earnings?['this_month']?.toStringAsFixed(2) ?? '0.00'}',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _earningsPeriodCard(
                  icon: Icons.pending_actions,
                  label: 'Pending',
                  value:
                      '\$${_earnings?['pending']?.toStringAsFixed(2) ?? '0.00'}',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ✅ Delivery Stats
          const Text(
            'Delivery Stats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _statsCard(
                  icon: Icons.check_circle,
                  label: 'Delivered',
                  value: '${_stats?['delivered'] ?? 0}',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statsCard(
                  icon: Icons.local_shipping,
                  label: 'In Transit',
                  value: '${_stats?['in_transit'] ?? 0}',
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statsCard(
                  icon: Icons.pending_actions,
                  label: 'Pending',
                  value: '${_stats?['pending'] ?? 0}',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statsCard(
                  icon: Icons.cancel,
                  label: 'Cancelled',
                  value: '${_stats?['cancelled'] ?? 0}',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

// ✅ Earnings Period Card
  Widget _earningsPeriodCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _darkColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryColor, Color(0xFF0D47A1)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, Rider 👋',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.fullName.isNotEmpty
                      ? widget.user.fullName
                      : 'Delivery Person',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadAll,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.refresh_rounded,
                  color: _darkColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATS BAR ====================
  Widget _buildStatsBar() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            icon: Icons.check_circle,
            label: 'Today',
            value: '${_stats!['delivered'] ?? 0}',
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          _statItem(
            icon: Icons.pending_actions,
            label: 'Pending',
            value: '${_stats!['pending'] ?? 0}',
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          _statItem(
            icon: Icons.attach_money,
            label: 'Total',
            value: '\$${_stats!['total_earned'] ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== TAB BAR ====================
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Pending (${_pending.length})'),
            ),
          ),
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Transit (${_inTransit.length})'),
            ),
          ),
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Done (${_completed.length})'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ORDER LIST ====================
  Widget _buildOrderList(List<DeliveryOrderModel> orders, String emptyMsg) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 50,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: orders.length,
        itemBuilder: (context, i) => _buildOrderCard(orders[i]),
      ),
    );
  }

  // ==================== ORDER CARD ====================
  Widget _buildOrderCard(DeliveryOrderModel order) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (order.status) {
      case 'confirmed':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'PENDING';
        statusIcon = Icons.pending_actions;
        break;
      case 'shipped':
        statusColor = _primaryColor;
        statusLabel = 'IN TRANSIT';
        statusIcon = Icons.local_shipping;
        break;
      case 'delivered':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'DELIVERED';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = order.status.toUpperCase();
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryOrderDetailScreen(
                  orderNumber: order.orderNumber,
                ),
              ),
            );
            _loadAll();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _darkColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.itemCount} item(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 16),
                _infoRow(
                  icon: Icons.person_outline,
                  label: order.customerName,
                  iconColor: _primaryColor,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  icon: Icons.phone_outlined,
                  label: order.customerPhone,
                  iconColor: _primaryColor,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  icon: Icons.location_on_outlined,
                  label: '${order.address}, ${order.city}',
                  iconColor: _primaryColor,
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            order.paymentMethod == 'cod'
                                ? Icons.money
                                : Icons.credit_card,
                            size: 14,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.paymentMethod.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '\$${order.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required Color iconColor,
    int maxLines = 2,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _darkColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red,
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _loadAll,
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
