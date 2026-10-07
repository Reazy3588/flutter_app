import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'order_chat_screen.dart';

import '../../services/chat_notification_service.dart';


class OrderTrackingScreen extends StatefulWidget {
  final String orderNumber;
  const OrderTrackingScreen({super.key, required this.orderNumber});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  final _dio = ApiService().dio;
  final _mapController = MapController();
  final _sheetController = DraggableScrollableController();

  Map<String, dynamic>? _tracking;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // ✅ Route
  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  double? _routeDuration;

  // ✅ Animations
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // ✅ ETA Countdown
  int _etaSeconds = 600;
  int _totalEtaSeconds = 600;
  Timer? _etaCountdownTimer;
  int _displayMinRange = 5;
  int _displayMaxRange = 15;

  // ✅ Map Ready
  bool _mapReady = false;

  static const Color _primaryColor = Color(0xFF1F6FEB);
  static const Color _darkColor = Color(0xFF0F172A);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();

    // Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide Animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _loadTracking();
    _startEtaCountdown();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadTracking();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _etaCountdownTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ==================== ETA COUNTDOWN ====================
  void _startEtaCountdown() {
    _etaCountdownTimer?.cancel();
    _etaCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_etaSeconds > 0) {
        setState(() {
          _etaSeconds--;
          _updateEtaDisplay();
        });
      }
    });
  }

  void _updateEtaDisplay() {
    final minutes = (_etaSeconds / 60).ceil();
    if (minutes < 5) {
      _displayMinRange = 1;
      _displayMaxRange = 5;
    } else if (minutes < 15) {
      _displayMinRange = 5;
      _displayMaxRange = 15;
    } else if (minutes < 30) {
      _displayMinRange = 15;
      _displayMaxRange = 30;
    } else {
      _displayMinRange = minutes;
      _displayMaxRange = minutes + 10;
    }
  }

  void _setEtaFromRoute(double? durationSeconds) {
    if (durationSeconds == null) return;
    _totalEtaSeconds = durationSeconds.round();
    _etaSeconds = _totalEtaSeconds;
    _updateEtaDisplay();
  }

  void _fitRouteOnMap() {
    if (_routePoints.isEmpty || !_mapReady) return;

    // រកចំណុចខ្លាំង
    double minLat = _routePoints[0].latitude;
    double maxLat = _routePoints[0].latitude;
    double minLng = _routePoints[0].longitude;
    double maxLng = _routePoints[0].longitude;

    for (final point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  // ==================== LOAD TRACKING ====================
  Future<void> _loadTracking() async {
    try {
      final response = await _dio.get(
        '/products/orders/${widget.orderNumber}/tracking/',
      );
      if (!mounted) return;

      setState(() {
        _tracking = response.data;
        _loading = false;
        _error = null;
      });

      _slideController.forward();

      final deliveryLat = response.data['delivery_lat'];
      final deliveryLng = response.data['delivery_lng'];
      final customerLat = response.data['customer_lat'];
      final customerLng = response.data['customer_lng'];

      if (deliveryLat != null &&
          deliveryLng != null &&
          customerLat != null &&
          customerLng != null) {
        await _fetchRoute();
      }

      if (deliveryLat != null && deliveryLng != null && _mapReady) {
        _mapController.move(
          LatLng(deliveryLat.toDouble(), deliveryLng.toDouble()),
          15.0,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_loadingRoute) return;
    setState(() => _loadingRoute = true);

    try {
      final response = await _dio.get(
        '/products/orders/${widget.orderNumber}/route/',
      );

      if (response.data['success'] == true) {
        final List<dynamic> points = response.data['points'];
        final List<LatLng> routePoints = points.map((point) {
          return LatLng(
            (point[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _routePoints = routePoints;
            _routeDuration = response.data['duration'];
          });
          _setEtaFromRoute(response.data['duration']);
          _fitRouteOnMap();
        }
      }
    } catch (e) {
      debugPrint('Route error: $e');
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    final t = _tracking!;
    final status = t['status'] ?? 'pending';
    final deliveryPerson = t['delivery_person'];
    final deliveryLat = t['delivery_lat'];
    final deliveryLng = t['delivery_lng'];
    final customerLat = t['customer_lat'];
    final customerLng = t['customer_lng'];

    if (status == 'shipped' && deliveryLat != null && deliveryLng != null) {
      return _buildLiveMapScreen(
        deliveryLat: deliveryLat.toDouble(),
        deliveryLng: deliveryLng.toDouble(),
        customerLat: customerLat?.toDouble(),
        customerLng: customerLng?.toDouble(),
        deliveryPerson: deliveryPerson,
        status: status,
      );
    }

    return _buildStatusScreen(status);
  }

  // ============================================================
  // 🗺️ MODERN LIVE MAP SCREEN
  // ============================================================
  Widget _buildLiveMapScreen({
    required double deliveryLat,
    required double deliveryLng,
    double? customerLat,
    double? customerLng,
    Map<String, dynamic>? deliveryPerson,
    required String status,
  }) {
    final deliveryLocation = LatLng(deliveryLat, deliveryLng);
    final customerLocation = customerLat != null && customerLng != null
        ? LatLng(customerLat, customerLng)
        : const LatLng(11.5564, 104.9282);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mapReady && mounted) {
        setState(() => _mapReady = true);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ==================== MAP ====================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: deliveryLocation,
              initialZoom: 12.5, // ✅ កាត់ពី 15 → 12.5
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecommerce_app',
                maxZoom: 19,
              ),

              // Route Polyline with Glow
              if (_routePoints.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 12.0,
                      color: _primaryColor.withOpacity(0.2),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: _primaryColor,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              ],

              // Markers
              MarkerLayer(
                markers: [
                  Marker(
                    point: deliveryLocation,
                    width: 80,
                    height: 80,
                    child: _buildRiderMarker(),
                  ),
                  if (customerLat != null)
                    Marker(
                      point: customerLocation,
                      width: 70,
                      height: 70,
                      child: _buildCustomerMarker(),
                    ),
                ],
              ),
            ],
          ),

          // ==================== TOP FLOATING CONTROLS ====================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildFloatingButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _buildFloatingPill(
                    icon: Icons.help_outline,
                    label: 'Help',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // ==================== BOTTOM SHEET ====================
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.40, // ✅ កាត់ពី 0.55 → 0.40
            minChildSize: 0.25, // ✅ កាត់ពី 0.42 → 0.25
            maxChildSize: 0.85, // ✅ កាត់ពី 0.9 → 0.85
            builder: (context, scrollController) {
              return SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28), // ✅ កាត់ពី 36 → 28
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Drag Handle
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 45,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ==================== MODERN ETA CARD ====================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14), // ✅ កាត់ពី 18 → 14
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1F6FEB),
                                Color(0xFF6366F1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(18), // ✅ កាត់ពី 22 → 18
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ========== LEFT: ETA Info ==========
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ETA Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_filled_rounded,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'ETA',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // ETA Number
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        TweenAnimationBuilder<int>(
                                          key: ValueKey<int>(_displayMinRange),
                                          tween: IntTween(
                                            begin: _displayMinRange - 1,
                                            end: _displayMinRange,
                                          ),
                                          duration:
                                              const Duration(milliseconds: 400),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, value, _) {
                                            return Text(
                                              '$value',
                                              style: const TextStyle(
                                                fontSize:
                                                    32, // ✅ កាត់ពី 38 → 32
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                height: 1,
                                                letterSpacing: -1,
                                              ),
                                            );
                                          },
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 2),
                                          child: Text(
                                            '—',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w300,
                                              color: Colors.white70,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                        TweenAnimationBuilder<int>(
                                          key: ValueKey<int>(_displayMaxRange),
                                          tween: IntTween(
                                            begin: _displayMaxRange - 1,
                                            end: _displayMaxRange,
                                          ),
                                          duration:
                                              const Duration(milliseconds: 400),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, value, _) {
                                            return Text(
                                              '$value',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                height: 1,
                                                letterSpacing: -1,
                                              ),
                                            );
                                          },
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(
                                              left: 4, bottom: 3),
                                          child: Text(
                                            'mins',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // Status
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 11,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _routePoints.isNotEmpty
                                                ? 'Fastest route'
                                                : 'Calculating...',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // ========== RIGHT: Rider Icon ==========
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale:
                                        0.95 + (_pulseController.value * 0.06),
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 56, // ✅ កាត់ពី 80 → 56
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.delivery_dining_rounded,
                                    size: 28, // ✅ កាត់ពី 36 → 28
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ==================== RIDER CARD ====================
                      if (deliveryPerson != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1F6FEB),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryColor.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.sports_motorsports_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deliveryPerson['name'] ?? 'Rider',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: _darkColor,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '4.9',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _darkColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade400,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Motorbike',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final phone = deliveryPerson['phone'];
                                    if (phone != null && phone.isNotEmpty) {
                                      final uri = Uri.parse('tel:$phone');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _successColor.withOpacity(0.4),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.phone_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
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
                                  child: AnimatedBuilder(
                                    animation: ChatNotificationService(),
                                    builder: (context, child) {
                                      final unread = ChatNotificationService()
                                                  .unreadByOrder[
                                              widget.orderNumber] ??
                                          0;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF1F6FEB),
                                                  Color(0xFF6366F1),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.chat_bubble_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                          // ✅ Badge
                                          if (unread > 0)
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 18,
                                                        minHeight: 18),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFEF4444),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFFEF4444)
                                                          .withOpacity(0.5),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    unread > 9
                                                        ? '9+'
                                                        : '$unread',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // ==================== TRACKING PROGRESS (COMPACT) ====================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                      7), // ✅ កាត់ពី 10 → 7
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.timeline_rounded,
                                    color: _primaryColor,
                                    size: 16, // ✅ កាត់ពី 20 → 16
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Order Timeline',
                                  style: TextStyle(
                                    fontSize: 14, // ✅ កាត់ពី 16 → 14
                                    fontWeight: FontWeight.w900,
                                    color: _darkColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: List.generate(3, (i) {
                                final steps = [
                                  {
                                    'label': 'Confirmed',
                                    'icon': Icons.check_rounded
                                  },
                                  {
                                    'label': 'Picked Up',
                                    'icon': Icons.local_shipping_rounded
                                  },
                                  {
                                    'label': 'Delivered',
                                    'icon': Icons.home_rounded
                                  },
                                ];
                                int currentStep = 0;
                                if (status == 'shipped') currentStep = 1;
                                if (status == 'delivered') currentStep = 2;
                                final done = i <= currentStep;

                                return Expanded(
                                  child: Row(
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            width: 28, // ✅ កាត់ពី 36 → 28
                                            height: 28,
                                            decoration: BoxDecoration(
                                              gradient: done
                                                  ? const LinearGradient(
                                                      colors: [
                                                        Color(0xFF1F6FEB),
                                                        Color(0xFF10B981),
                                                      ],
                                                    )
                                                  : null,
                                              color: done
                                                  ? null
                                                  : Colors.grey.shade200,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              steps[i]['icon'] as IconData,
                                              size: 14, // ✅ កាត់ពី 18 → 14
                                              color: done
                                                  ? Colors.white
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            steps[i]['label'] as String,
                                            style: TextStyle(
                                              fontSize: 9, // ✅ កាត់ពី 10 → 9
                                              fontWeight: done
                                                  ? FontWeight.w900
                                                  : FontWeight.w500,
                                              color: done
                                                  ? _darkColor
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (i < 2)
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 20),
                                            child: Container(
                                              height: 2,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 3),
                                              decoration: BoxDecoration(
                                                gradient: i < currentStep
                                                    ? const LinearGradient(
                                                        colors: [
                                                          Color(0xFF1F6FEB),
                                                          Color(0xFF10B981),
                                                        ],
                                                      )
                                                    : null,
                                                color: i < currentStep
                                                    ? null
                                                    : Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(1),
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
                      ),

                      const SizedBox(height: 24),

                      // ==================== ORDER NUMBER ====================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _primaryColor.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                  color: _primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Number',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.orderNumber,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _darkColor,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== PROGRESS TIMELINE ====================
  Widget _buildProgressTimeline(String status) {
    final steps = [
      {'label': 'Confirmed', 'icon': Icons.check_rounded},
      {'label': 'Picked Up', 'icon': Icons.local_shipping_rounded},
      {'label': 'Delivered', 'icon': Icons.home_rounded},
    ];

    int currentStep = 0;
    if (status == 'shipped') currentStep = 1;
    if (status == 'delivered') currentStep = 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.timeline_rounded,
                color: _primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Order Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _darkColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 44 * _pulseAnimation.value,
                                  height: 44 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    color: _successColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              },
                            ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: done
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF1F6FEB),
                                        Color(0xFF10B981),
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
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              steps[i]['icon'] as IconData,
                              size: 18,
                              color: done ? Colors.white : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: done ? FontWeight.w900 : FontWeight.w500,
                          color: done ? _darkColor : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 26),
                        child: Container(
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
                            color:
                                i < currentStep ? null : Colors.grey.shade200,
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
    );
  }

  // ==================== RIDER MARKER ====================
  Widget _buildRiderMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 70 * _pulseAnimation.value,
              height: 70 * _pulseAnimation.value,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F6FEB), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.sports_motorsports_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _successColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _successColor.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== CUSTOMER MARKER ====================
  Widget _buildCustomerMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _darkColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF334155)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ==================== FLOATING BUTTONS ====================
  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: _darkColor),
      ),
    );
  }

  Widget _buildFloatingPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _darkColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _darkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STATUS SCREEN ====================
  Widget _buildStatusScreen(String status) {
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;

    if (status == 'delivered') {
      icon = Icons.check_circle;
      iconColor = _successColor;
      title = 'Delivered';
      subtitle = 'Your order has been delivered. Thank you!';
    } else if (status == 'confirmed') {
      icon = Icons.check_circle;
      iconColor = _primaryColor;
      title = 'Confirmed';
      subtitle = 'Your order is confirmed. Waiting for rider...';
    } else if (status == 'pending') {
      icon = Icons.schedule;
      iconColor = _warningColor;
      title = 'Pending';
      subtitle = 'Waiting for shop confirmation...';
    } else {
      icon = Icons.info;
      iconColor = Colors.grey;
      title = status.toUpperCase();
      subtitle = 'Please wait...';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkColor,
        elevation: 0,
        title: Text(
          widget.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 70, color: iconColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _darkColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ERROR SCREEN ====================
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Please check your network connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
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
                  _loadTracking();
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
}
