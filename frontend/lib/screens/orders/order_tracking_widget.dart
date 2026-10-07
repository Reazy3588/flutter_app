import 'dart:async';
import 'package:flutter/material.dart';

class OrderTrackingWidget extends StatefulWidget {
  final String currentStatus;
  final String? statusUpdatedAt;

  const OrderTrackingWidget({
    super.key,
    required this.currentStatus,
    this.statusUpdatedAt,
  });

  @override
  State<OrderTrackingWidget> createState() => _OrderTrackingWidgetState();
}

class _OrderTrackingWidgetState extends State<OrderTrackingWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;

  final List<Map<String, dynamic>> _steps = [
    {'key': 'pending', 'label': 'Pending', 'icon': Icons.hourglass_empty},
    {'key': 'shipped', 'label': 'Shipped', 'icon': Icons.local_shipping},
    {
      'key': 'delivered',
      'label': 'Delivered',
      'icon': Icons.check_circle_outline
    },
    {'key': 'confirmed', 'label': 'Confirmed', 'icon': Icons.verified},
  ];

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    // ប្រសិនបើ Status គឺ 'shipped' យើងចាប់ផ្តើមរាប់ថយក្រោយ ៥ នាទី (៣០០ វិនាទី)
    if (widget.currentStatus == 'shipped' && widget.statusUpdatedAt != null) {
      final updatedTime = DateTime.parse(widget.statusUpdatedAt!);
      final targetTime = updatedTime.add(const Duration(minutes: 5));
      final now = DateTime.now();

      if (now.isBefore(targetTime)) {
        _remainingSeconds = targetTime.difference(now).inSeconds;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_remainingSeconds > 0) {
            setState(() => _remainingSeconds--);
          } else {
            _timer?.cancel();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _getCurrentStepIndex() {
    return _steps.indexWhere((step) => step['key'] == widget.currentStatus);
  }

  @override
  Widget build(BuildContext context) {
    int currentIndex = _getCurrentStepIndex();
    if (currentIndex == -1) currentIndex = 0;

    return Column(
      children: [
        Row(
          children: List.generate(_steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              // បន្ទាត់តភ្ជាប់
              int stepIndex = index ~/ 2;
              bool isCompleted = stepIndex < currentIndex;
              return Expanded(
                child: Container(
                  height: 4,
                  color: isCompleted
                      ? const Color(0xFF1F6FEB)
                      : Colors.grey.shade300,
                ),
              );
            } else {
              // ចំណុច (Circle)
              int stepIndex = index ~/ 2;
              bool isCompleted = stepIndex <= currentIndex;
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isCompleted ? const Color(0xFF1F6FEB) : Colors.white,
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF1F6FEB)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _steps[stepIndex]['icon'],
                      color: isCompleted ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _steps[stepIndex]['label'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              );
            }
          }),
        ),

        // បង្ហាញ Timer ប្រសិនបើកំពុង Shipped
        if (widget.currentStatus == 'shipped' && _remainingSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Delivery in: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
