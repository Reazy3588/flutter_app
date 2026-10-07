import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Phnom Penh default
  LatLng _selected = const LatLng(11.5564, 104.9282);
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  bool _satellite = false;
  bool _locating = false;
  bool _searching = false;
  bool _loadingAddress = false;
  List<Map<String, dynamic>> _results = [];
  LatLng? _myLocation;

  // ✅ Address data ដែលទាញបានពី Reverse Geocoding
  String _addressLine = '';
  String _city = '';

  static const Color primary = Color(0xFF1F6FEB);

  @override
  void initState() {
    super.initState();
    _goToMyLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- 📍 Real-time location ----------
  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
        _selected = _myLocation!;
      });
      _mapController.move(_myLocation!, 17);
      _reverseGeocode(_myLocation!); // ✅ ទាញ Address ភ្លាម
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------- Search (Nominatim) ----------
  Future<void> _search(String query) async {
    if (query.trim().length < 3) return;
    setState(() => _searching = true);
    try {
      final res = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5'),
        headers: {'User-Agent': 'ecommerce-app'},
      );
      final List data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) => {
                  'name': e['display_name'] as String,
                  'lat': double.parse(e['lat']),
                  'lon': double.parse(e['lon']),
                })
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ---------- ✅ Reverse Geocoding — ទាញ Address + City ----------
  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _loadingAddress = true);
    try {
      final res = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${p.latitude}&lon=${p.longitude}&addressdetails=1'),
        headers: {'User-Agent': 'ecommerce-app'},
      );
      final data = jsonDecode(res.body);
      final address = data['address'] ?? {};

      final road = address['road'] ??
          address['pedestrian'] ??
          address['footway'] ??
          address['suburb'] ??
          '';
      final houseNumber = address['house_number'] ?? '';
      final city = address['city'] ??
          address['town'] ??
          address['state'] ??
          address['province'] ??
          '';

      if (!mounted) return;
      setState(() {
        _addressLine =
            houseNumber.isNotEmpty ? '$houseNumber $road' : road.toString();
        _city = city.toString();
        _loadingAddress = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _confirm() async {
    if (_addressLine.isEmpty) {
      await _reverseGeocode(_selected);
    }
    if (!mounted) return;
    Navigator.pop(context, {
      'lat': _selected.latitude,
      'lng': _selected.longitude,
      'addressLine': _addressLine,
      'city': _city,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ---------- Map ----------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 15,
              onTap: (tapPos, point) {
                setState(() => _selected = point);
                _reverseGeocode(point);
              },
            ),
            children: [
              _satellite
                  ? TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      maxNativeZoom: 19,
                      userAgentPackageName: 'ecommerce-app',
                    )
                  : TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      maxNativeZoom: 19,
                      userAgentPackageName: 'ecommerce-app',
                      tileProvider:
                          CancellableNetworkTileProvider(), // ✅ បន្ថែមនេះ
                    ),
              if (_myLocation != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: _myLocation!,
                    radius: 20,
                    color: Colors.blue.withOpacity(0.15),
                    borderColor: Colors.blue.withOpacity(0.5),
                    borderStrokeWidth: 2,
                  ),
                ]),
              MarkerLayer(markers: [
                if (_myLocation != null)
                  Marker(
                    point: _myLocation!,
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                Marker(
                  point: _selected,
                  width: 56,
                  height: 56,
                  alignment: Alignment.topCenter,
                  child: const _AnimatedPin(),
                ),
              ]),
            ],
          ),

          // ---------- Modern Search Bar ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: "Search place (e.g. Siem Reap)...",
                        prefixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)))
                            : const Icon(Icons.search, color: primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place, color: primary),
                            title: Text(r['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            onTap: () {
                              setState(() {
                                _selected = LatLng(r['lat'], r['lon']);
                                _results = [];
                              });
                              _mapController.move(_selected, 17);
                              _reverseGeocode(_selected);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ---------- My Location Button ----------
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: "myLocation",
              backgroundColor: Colors.white,
              foregroundColor: primary,
              onPressed: _goToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),

          // ---------- Satellite Toggle ----------
          Positioned(
            right: 16,
            bottom: 300,
            child: FloatingActionButton(
              heroTag: "satellite",
              backgroundColor: Colors.white,
              foregroundColor: primary,
              onPressed: () => setState(() => _satellite = !_satellite),
              child:
                  Icon(_satellite ? Icons.map_outlined : Icons.satellite_alt),
            ),
          ),

          // ---------- Bottom Sheet ----------
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on,
                            color: primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Selected Location",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _loadingAddress
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    _addressLine.isNotEmpty
                                        ? _addressLine
                                        : "Tap map to select",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                            if (_city.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loadingAddress ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "Confirm Location",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        ],
      ),
    );
  }
}

// ============================================================
// ✅ Animated Pin Widget — កែ Error រួច
// ============================================================
class _AnimatedPin extends StatefulWidget {
  const _AnimatedPin({super.key});

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1F6FEB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F6FEB).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _TrianglePainter(),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ✅ Triangle Painter — កែ Error រួច
// ============================================================
// ============================================================
// ✅ Triangle Painter — កែ Error រួច
// ============================================================
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    paint.color = const Color(0xFF1F6FEB);
    paint.style = PaintingStyle.fill;

    // ✅ ប្រើ ui.Path ដើម្បីកុំឱ្យ Conflict ជាមួយ Path របស់ latlong2
    final ui.Path path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
