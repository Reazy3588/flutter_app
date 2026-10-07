import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ChatNotificationService extends ChangeNotifier {
  static final ChatNotificationService _instance =
      ChatNotificationService._internal();
  factory ChatNotificationService() => _instance;
  ChatNotificationService._internal();

  final _dio = ApiService().dio;

  int _unreadCount = 0;
  Map<String, int> _unreadByOrder = {};
  Timer? _pollTimer;
  bool _isPolling = false;

  int get unreadCount => _unreadCount;
  Map<String, int> get unreadByOrder => _unreadByOrder;

  /// ✅ ចាប់ផ្តើម Polling
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    if (_isPolling) return;
    _isPolling = true;
    _pollTimer?.cancel();
    _fetchUnreadCount(); // ទាញភ្លាម
    _pollTimer = Timer.periodic(interval, (_) => _fetchUnreadCount());
  }

  /// ✅ បញ្ឈប់ Polling
  void stopPolling() {
    _isPolling = false;
    _pollTimer?.cancel();
  }

  /// ✅ ទាញចំនួនសារដែលមិនទាន់អាន
  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _dio.get('/products/chat/unread/');
      final total = res.data['total'] ?? 0;
      final orders = res.data['orders'] as List? ?? [];

      final Map<String, int> newMap = {};
      for (final item in orders) {
        newMap[item['order__order_number']] = item['count'];
      }

      // ✅ ប្រៀបធៀបដើម្បីដឹងថាមានសារថ្មី
      final hasNewMessage = total > _unreadCount;

      _unreadCount = total;
      _unreadByOrder = newMap;

      notifyListeners();

      // ✅ បង្ហាញ In-App Notification ប្រសិនបើមានសារថ្មី
      if (hasNewMessage && _isPolling) {
        _showInAppNotification();
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// ✅ បង្ហាញ Notification ក្នុង App
  void _showInAppNotification() {
    // ប្រើ Global Navigator Key ដើម្បីបង្ហាញ SnackBar
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '💬 New Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'You have $_unreadCount unread message${_unreadCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F6FEB),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// ✅ កំណត់ Navigator Key (ពី main.dart)
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// ✅ Mark as read
  Future<void> markAsRead(String orderNumber) async {
    try {
      await _dio.post('/products/orders/$orderNumber/chat/read/');
      _unreadByOrder.remove(orderNumber);
      _unreadCount = _unreadByOrder.values.fold(0, (a, b) => a + b);
      notifyListeners();
    } catch (_) {}
  }

  /// ✅ Reset
  void reset() {
    _unreadCount = 0;
    _unreadByOrder = {};
    notifyListeners();
  }
}
