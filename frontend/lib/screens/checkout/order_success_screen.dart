import 'package:flutter/material.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderNumber;
  const OrderSuccessScreen({super.key, required this.orderNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 90),
            const SizedBox(height: 16),
            const Text("Order Placed! 🎉",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("$orderNumber confirmed",
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                // ត្រឡប់ទៅ Home (លុបទាំង stack)
                Navigator.pop(context);
              },
              child: const Text("Continue Shopping"),
            ),
          ],
        ),
      ),
    );
  }
}
