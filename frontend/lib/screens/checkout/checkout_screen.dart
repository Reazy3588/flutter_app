import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/address_model.dart';
import '../../models/cart.dart';
import '../../services/address_service.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../payment/aba_payway_screen.dart';
import 'order_success_screen.dart';
import '../payment/bakong_payment_screen.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressService = AddressService();
  final _orderService = OrderService();
  final _cartService = CartService();

  List<AddressModel> _addresses = [];
  AddressModel? _selected;
  Cart? _cart;

  String _paymentMethod = 'cod';

  bool _loading = true;
  bool _placing = false;
  bool _checkingCoupon = false; // ✅ បន្ថែមនេះ

  // ================= COUPON VARIABLES =================
  final TextEditingController _couponController = TextEditingController();
  String _appliedCoupon = '';
  double _discountAmount = 0.0;

  static const Color primary = Color(0xFF1F6FEB);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD ADDRESS + CART
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final results = await Future.wait([
        _addressService.getAddresses(),
        _cartService.getCart(),
      ]);

      final List<AddressModel> addresses = results[0] as List<AddressModel>;
      final Cart cart = results[1] as Cart;

      if (!mounted) return;

      AddressModel? selected;
      if (addresses.isNotEmpty) {
        try {
          selected = addresses.firstWhere((address) => address.isDefault);
        } catch (_) {
          selected = addresses.first;
        }
      }

      setState(() {
        _addresses = addresses;
        _selected = selected;
        _cart = cart;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack("❌ ${extractErrorMessage(e)}", Colors.red);
    }
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> _placeOrder() async {
    if (_cart == null || _cart!.items.isEmpty) {
      _snack("⚠️ Your cart is empty!", Colors.red);
      return;
    }

    if (_selected == null) {
      _snack("⚠️ Please select a shipping address", Colors.red);
      return;
    }

    if (_placing) return;
    setState(() => _placing = true);

    // គណនាតម្លៃសរុបចុងក្រោយ (ក្រោយបញ្ចុះតម្លៃ)
    double finalTotal = _cart!.grandTotal - _discountAmount;
    if (finalTotal < 0) finalTotal = 0;

    // ------------------------------------------------------------
    // BANK / QR PAYMENT
    // ------------------------------------------------------------

    if (_paymentMethod == 'aba' || _paymentMethod == 'acleda') {
      try {
        final String paymentRef =
            "PRE-${DateTime.now().millisecondsSinceEpoch % 100000}";
        final bool? paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AbaPaywayScreen(
              amount: finalTotal, // ប្រើតម្លៃក្រោយបញ្ចុះ
              orderRef: paymentRef,
              initialBank: _paymentMethod,
            ),
          ),
        );

        if (!mounted) return;
        if (paid != true) {
          setState(() => _placing = false);
          _snack("❌ Payment cancelled", Colors.red);
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _placing = false);
        _snack("❌ Payment failed: ${extractErrorMessage(e)}", Colors.red);
        return;
      }
    } else if (_paymentMethod == 'bakong') {
      try {
        final String paymentRef =
            "PRE-${DateTime.now().millisecondsSinceEpoch % 100000}";
        final bool? paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BakongPaymentScreen(
              amount: finalTotal, // ប្រើតម្លៃក្រោយបញ្ចុះ
              orderRef: paymentRef,
            ),
          ),
        );

        if (!mounted) return;
        if (paid != true) {
          setState(() => _placing = false);
          _snack("❌ Payment cancelled", Colors.red);
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _placing = false);
        _snack("❌ Payment failed: ${extractErrorMessage(e)}", Colors.red);
        return;
      }
    }

    // ------------------------------------------------------------
    // CREATE ORDER
    // ------------------------------------------------------------

    try {
      final order = await _orderService.checkout(
        addressId: _selected!.id,
        paymentMethod: _paymentMethod,
        couponCode: _appliedCoupon,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            orderNumber: order.orderNumber,
            paymentMethod: _paymentMethod,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      _snack("❌ ${extractErrorMessage(e)}", Colors.red);
    }
  }

  // ============================================================
  // APPLY COUPON
  // ============================================================

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();

    if (code.isEmpty) {
      _snack("⚠️ Please enter a coupon code", Colors.orange);
      return;
    }

    setState(() => _checkingCoupon = true);

    try {
      final res = await _orderService.validateCoupon(code);

      if (!mounted) return;

      final rawDiscount = res['discount_amount'] ?? 0;
      final discountAmount = num.tryParse(rawDiscount.toString()) ?? 0;
      final validatedCode = (res['code'] ?? code).toString();
      final message = (res['message'] ?? 'Coupon applied').toString();

      setState(() {
        _appliedCoupon = validatedCode;
        _discountAmount = discountAmount.toDouble();
        _checkingCoupon = false;
      });

      _snack("✅ $message", Colors.green);
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _appliedCoupon = '';
        _discountAmount = 0.0;
        _checkingCoupon = false;
      });

      String errorMsg = "Invalid coupon";
      final data = e.response?.data;

      if (data is Map) {
        if (data['error'] != null) {
          errorMsg = data['error'].toString();
        } else if (data['message'] != null) {
          errorMsg = data['message'].toString();
        } else if (data['detail'] != null) {
          errorMsg = data['detail'].toString();
        } else if (data['non_field_errors'] != null) {
          final errors = data['non_field_errors'];
          if (errors is List && errors.isNotEmpty) {
            errorMsg = errors.first.toString();
          }
        }
      }

      _snack("❌ $errorMsg", Colors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedCoupon = '';
        _discountAmount = 0.0;
        _checkingCoupon = false;
      });
      _snack("❌ ${extractErrorMessage(e)}", Colors.red);
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

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

  // ============================================================
  // FORMAT MONEY
  // ============================================================

  String _money(double value) {
    return "\$${value.toStringAsFixed(2)}";
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cart = _cart;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Checkout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // 1. SHIPPING ADDRESS
          // ======================================================
          _sectionTitle("📍 Shipping Address"),
          if (_addresses.isEmpty)
            _card(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined,
                        size: 42, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text("No shipping address yet",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      "Please add a shipping address first.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          else
            _card(
              Column(
                children: _addresses.map((a) {
                  final String label =
                      a.label.isNotEmpty ? "${a.label} • " : "";
                  final String defaultText = a.isDefault ? "  ⭐" : "";
                  final String addressText = "${a.addressLine}, ${a.city}";

                  return RadioListTile<AddressModel>(
                    value: a,
                    groupValue: _selected,
                    activeColor: primary,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selected = value);
                    },
                    title: Text(
                      "$label${a.fullName}$defaultText",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${a.phoneNumber} • $addressText",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 20),

          // ======================================================
          // 2. PAYMENT METHOD
          // ======================================================
          _sectionTitle("💳 Payment Method"),
          _card(
            Column(
              children: [
                RadioListTile<String>(
                  value: 'cod',
                  groupValue: _paymentMethod,
                  activeColor: primary,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
                  title: const Text("💵 Cash on Delivery",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Pay when the order arrives",
                      style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<String>(
                  value: 'aba',
                  groupValue: _paymentMethod,
                  activeColor: primary,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
                  title: const Text("🏦 ABA PayWay",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Card / QR payment",
                      style: TextStyle(fontSize: 12)),
                ),
                if (_paymentMethod == 'aba')
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You will be redirected to the demo payment gateway before the order is created.",
                            style:
                                TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<String>(
                  value: 'acleda',
                  groupValue: _paymentMethod,
                  activeColor: primary,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
                  title: const Text("🏦 ACLEDA Bank",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Scan QR with ACLEDA Mobile",
                      style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<String>(
                  value: 'bakong',
                  groupValue: _paymentMethod,
                  activeColor: primary,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
                  title: const Text("🇰🇭 Bakong (KHQR)",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Scan with any KHQR-supported bank app",
                      style: TextStyle(fontSize: 12)),
                ),
                if (_paymentMethod == 'bakong')
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "A KHQR code will be generated for this order before it's placed.",
                            style:
                                TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ======================================================
          // 3. ORDER SUMMARY (រួមទាំង Coupon)
          // ======================================================
          _sectionTitle("🧾 Order Summary"),
          _card(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow("Subtotal (${cart?.count ?? 0} items)",
                      cart?.subtotal ?? 0),
                  const SizedBox(height: 10),
                  _summaryRow("Shipping Fee", cart?.shipping ?? 0),
                  const SizedBox(height: 10),
                  _summaryRow(
                      "Tax (1%)", cart?.tax ?? 0), // ✅ បង្ហាញក្នុង Checkout

                  // ================= COUPON INPUT =================
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: "Enter coupon code",
                            hintStyle: const TextStyle(fontSize: 13),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _checkingCoupon ? null : _applyCoupon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _checkingCoupon
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Apply"),
                      ),
                    ],
                  ),

                  // បង្ហាញពីការបញ្ចុះតម្លៃ (បើមាន)
                  if (_discountAmount > 0) ...[
                    const SizedBox(height: 12),
                    _summaryRow("Discount ($_appliedCoupon)", -_discountAmount),
                  ],

                  const Divider(height: 24),

                  // Grand Total (កែឱ្យដកតម្លៃបញ្ចុះ)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          "Grand Total",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        _money((cart?.grandTotal ?? 0) - _discountAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // 4. PLACE ORDER BUTTON
          // ======================================================
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _placing ? null : _placeOrder,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _placing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text("Processing...",
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 19),
                        const SizedBox(width: 8),
                        Text(
                          _paymentMethod == 'aba' ||
                                  _paymentMethod == 'acleda' ||
                                  _paymentMethod == 'bakong'
                              ? "Continue to Payment"
                              : "Place Order",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 15, color: Colors.grey.shade500),
              const SizedBox(width: 5),
              Text("Secure checkout",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ),
        const SizedBox(width: 12),
        Text(
          _money(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value < 0
                ? Colors.green
                : Colors.black87, // ពណ៌បៃតងពេលបញ្ចុះតម្លៃ
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _card(Widget child) {
    return Container(
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
      child: child,
    );
  }
}
