import 'package:flutter/material.dart';
import '../../models/cart.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../checkout/checkout_screen.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart'; // ✅ សម្រាប់ "Start Shopping" Button
import '../../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  final _authService = AuthService();
  Cart? cart;
  bool isLoading = true;

  static const Color primary = Color(0xFF1F6FEB);

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  Future<void> loadCart() async {
    try {
      final c = await _cartService.getCart();
      setState(() {
        cart = c;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateQty(CartItem item, int newQty) async {
    if (newQty < 1) return;
    if (newQty > item.stock) {
      _snack("⚠️ Only ${item.stock} item(s) in stock", Colors.orange);
      return;
    }
    try {
      await _cartService.updateQuantity(item.id, newQty);
      loadCart();
    } catch (e) {
      _snack("❌ ${extractErrorMessage(e)}", Colors.red);
    }
  }

  Future<void> deleteItem(CartItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Item?"),
        content: Text("Remove ${item.name} from cart?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _cartService.deleteItem(item.id);
    loadCart();
  }

  Future<void> _proceedToCheckout() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (!isLoggedIn) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Login Required"),
          content:
              const Text("Please login or sign up to proceed to checkout."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: primary),
              child: const Text("Login"),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = cart?.items ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          "My Cart (${cart?.count ?? 0})",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: items.isEmpty ? _buildEmptyState() : _buildCartContent(items),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.08),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 60,
                color: primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Your Cart is Empty",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Looks like you haven't added\nanything to your cart yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const HomeScreen(user: null)),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.storefront_rounded, size: 20),
                label: const Text(
                  "Start Shopping",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CART CONTENT =================
  Widget _buildCartContent(List<CartItem> items) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildCartItem(items[i]),
          ),
        ),
        _buildPriceSummary(),
      ],
    );
  }

  // ================= CART ITEM CARD =================
  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ រូបភាពផលិតផល
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(6),
              child: item.image != null && item.image!.isNotEmpty
                  ? Image.network(
                      item.image!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
                    )
                  : Icon(
                      Icons.image_outlined,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
            ),
            const SizedBox(width: 12),

            // ✅ ព័ត៌មានផលិតផល
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.categoryName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.categoryName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

// ✅ បន្ថែម Color/Variant Display
                  if (item.variantOptions != null &&
                      item.variantOptions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.variantOptions!.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join(' | '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    "\$${item.price.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ✅ Quantity Controls
                  Row(
                    children: [
                      _qtyButton(
                        icon: Icons.remove,
                        onTap: () => updateQty(item, item.quantity - 1),
                        enabled: item.quantity > 1,
                      ),
                      Container(
                        width: 44,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${item.quantity}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _qtyButton(
                        icon: Icons.add,
                        onTap: () => updateQty(item, item.quantity + 1),
                        enabled: item.quantity < item.stock,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => deleteItem(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: enabled ? primary.withOpacity(0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? primary : Colors.grey.shade400,
        ),
      ),
    );
  }

  // ================= PRICE SUMMARY =================
  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _row("Subtotal", cart!.subtotal),
          const SizedBox(height: 8),
          _row("Shipping Fee", cart!.shipping),
          // ✅ លាក់ Tax ក្នុង Cart (បង្ហាញតែក្នុង Checkout)
          // const SizedBox(height: 8),
          // _row("Tax (1%)", cart!.tax),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Grand Total",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "\$${cart!.grandTotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _proceedToCheckout,
              icon: const Icon(Icons.shopping_bag_rounded, size: 20),
              label: const Text(
                "Proceed to Checkout",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13.5, color: Colors.black54)),
        Text(
          "\$${value.toStringAsFixed(2)}",
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
