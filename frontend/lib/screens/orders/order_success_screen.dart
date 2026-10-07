import 'package:flutter/material.dart';
import '../orders/my_orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderNumber;
  const OrderSuccessScreen({super.key, required this.orderNumber});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1F6FEB);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Animated check icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 80),
                ),
                const SizedBox(height: 24),
                const Text("Order Placed Successfully! 🎉",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Your order $orderNumber is confirmed",
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 14)),
                const SizedBox(height: 8),
                const Text("We will contact you soon for delivery 🚚",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 40),

                // 👈 Button 1: View My Orders
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((r) => r.isFirst); // លុប stack → Home
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyOrdersScreen()));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("View My Orders",
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),

                // 👈 Button 2: Continue Shopping
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: const BorderSide(color: primary),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Continue Shopping",
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
