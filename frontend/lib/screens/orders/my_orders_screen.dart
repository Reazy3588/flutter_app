import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'order_tracking_screen.dart';
import 'order_detail_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // ==================== MODERN SLIVER APP BAR ====================
              SliverAppBar(
                expandedHeight: 170,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF1F6FEB),
                elevation: 0,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1F6FEB),
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative Blobs
                        Positioned(
                          top: -80,
                          right: -80,
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -100,
                          left: -60,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Orders',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.8,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Track all your orders in real-time',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: const Color(0xFF1F6FEB),
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Active'),
                        Tab(text: 'Completed'),
                        Tab(text: 'Cancelled'),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: [
              _OrderTab(statuses: ['pending', 'confirmed', 'shipped']),
              _OrderTab(statuses: ['delivered']),
              _OrderTab(statuses: ['cancelled']),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAB WIDGET
// ============================================================

class _OrderTab extends StatefulWidget {
  final List<String> statuses;
  const _OrderTab({required this.statuses});

  @override
  State<_OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<_OrderTab>
    with AutomaticKeepAliveClientMixin {
  final _dio = ApiService().dio;
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final futures = widget.statuses.map((status) {
        return _dio.get(
          '/products/orders/',
          queryParameters: {'status': status},
        );
      }).toList();

      final responses = await Future.wait(futures);
      final List<dynamic> allOrders = [];
      for (final res in responses) {
        if (res.data is List) {
          allOrders.addAll(res.data as List);
        }
      }

      allOrders.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _orders = allOrders;
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
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1F6FEB)),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_orders.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: const Color(0xFF1F6FEB),
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          return _ModernOrderCard(
            order: _orders[index],
            onRefresh: _loadOrders,
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1F6FEB).withOpacity(0.15),
                  const Color(0xFF8B5CF6).withOpacity(0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 65,
              color: Color(0xFF1F6FEB),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your orders will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
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
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F6FEB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _loadOrders,
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

// ============================================================
// 🎴 MODERN ORDER CARD (2026 Style)
// ============================================================

class _ModernOrderCard extends StatefulWidget {
  final dynamic order;
  final VoidCallback onRefresh;

  const _ModernOrderCard({
    required this.order,
    required this.onRefresh,
  });

  @override
  State<_ModernOrderCard> createState() => _ModernOrderCardState();
}

class _ModernOrderCardState extends State<_ModernOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': 'PENDING',
          'icon': Icons.schedule_rounded,
          'color': const Color(0xFFF59E0B),
          'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        };
      case 'confirmed':
        return {
          'label': 'CONFIRMED',
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF3B82F6),
          'gradient': [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        };
      case 'shipped':
        return {
          'label': 'IN TRANSIT',
          'icon': Icons.local_shipping_rounded,
          'color': const Color(0xFF8B5CF6),
          'gradient': [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
        };
      case 'delivered':
        return {
          'label': 'DELIVERED',
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF10B981),
          'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
        };
      case 'cancelled':
        return {
          'label': 'CANCELLED',
          'icon': Icons.cancel_rounded,
          'color': const Color(0xFFEF4444),
          'gradient': [const Color(0xFFEF4444), const Color(0xFFDC2626)],
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
    final order = widget.order;
    final status = order['status'] ?? 'pending';
    final orderNumber = order['order_number'] ?? '';
    final grandTotal = order['grand_total'] ?? '0';
    final itemCount = order['item_count'] ?? 0;
    final paymentMethod = order['payment_method'] ?? 'cod';
    final createdAt = order['created_at'];

    final config = _getStatusConfig(status);
    final statusColor = config['color'] as Color;
    final statusGradient = config['gradient'] as List<Color>;
    final statusIcon = config['icon'] as IconData;
    final statusLabel = config['label'] as String;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      orderNumber: orderNumber,
                    ),
                  ),
                );
                widget.onRefresh();
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================== HEADER ====================
                    Row(
                      children: [
                        // Animated Icon Box
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: statusGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            statusIcon,
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
                                orderNumber,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(createdAt),
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
                        ),

                        // Status Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: statusColor,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ==================== TRACKING PROGRESS ====================
                    if (status != 'cancelled') _buildTrackingProgress(status),

                    const SizedBox(height: 20),

                    // ==================== ORDER INFO ====================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1F6FEB).withOpacity(0.04),
                            const Color(0xFF8B5CF6).withOpacity(0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF1F6FEB).withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          _infoItem(
                            Icons.shopping_bag_rounded,
                            '$itemCount item${itemCount > 1 ? 's' : ''}',
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: Colors.grey.shade300,
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          _infoItem(
                            Icons.credit_card_rounded,
                            paymentMethod.toUpperCase(),
                          ),
                          const Spacer(),
                          Text(
                            '\$$grandTotal',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F6FEB),
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================== ACTION BUTTONS ====================
                    Row(
                      children: [
                        // Details Button
                        Expanded(
                          child: _modernButton(
                            icon: Icons.visibility_rounded,
                            label: 'Details',
                            isOutlined: true,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(
                                    orderNumber: orderNumber,
                                  ),
                                ),
                              );
                              widget.onRefresh();
                            },
                          ),
                        ),

                        // Track Button
                        if (status == 'shipped' || status == 'confirmed') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _modernButton(
                              icon: Icons.location_on_rounded,
                              label: 'Track',
                              isOutlined: false,
                              gradient: [
                                const Color(0xFF10B981),
                                const Color(0xFF059669),
                              ],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderTrackingScreen(
                                      orderNumber: orderNumber,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TRACKING PROGRESS ====================
  Widget _buildTrackingProgress(String status) {
    final steps = [
      {'label': 'Pending', 'icon': Icons.schedule_rounded},
      {'label': 'Confirmed', 'icon': Icons.check_circle_rounded},
      {'label': 'Transit', 'icon': Icons.local_shipping_rounded},
      {'label': 'Delivered', 'icon': Icons.home_rounded},
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
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
                        // Pulsing Ring for Current Step
                        if (isCurrent && status != 'delivered')
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F6FEB).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: done
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF1F6FEB),
                                      Color(0xFF10B981),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: done ? null : Colors.grey.shade200,
                            shape: BoxShape.circle,
                            boxShadow: done
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1F6FEB)
                                          .withOpacity(0.4),
                                      blurRadius: isCurrent ? 12 : 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            steps[i]['icon'] as IconData,
                            size: 15,
                            color: done ? Colors.white : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                        color: done
                            ? const Color(0xFF0F172A)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: i < currentStep
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF1F6FEB),
                                    Color(0xFF10B981),
                                  ],
                                )
                              : null,
                          color: i < currentStep ? null : Colors.grey.shade200,
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
    );
  }

  Widget _modernButton({
    required IconData icon,
    required String label,
    required bool isOutlined,
    required VoidCallback onTap,
    List<Color>? gradient,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1F6FEB),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(
            color: Color(0xFF1F6FEB),
            width: 1.5,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              gradient ?? [const Color(0xFF1F6FEB), const Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                (gradient?.first ?? const Color(0xFF1F6FEB)).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
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
