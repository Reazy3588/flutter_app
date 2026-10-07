import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/khqr_generator.dart';

/// Requirement #22 — Payment Gateway Prototype: Bakong (KHQR).
///
/// Generates a real, spec-compliant KHQR payload (see khqr_generator.dart)
/// and renders it as a scannable QR code. Any Cambodian banking app that
/// supports KHQR can scan this code.
///
/// ⚠️ DEMO MODE: true, live "did they actually pay?" verification requires
/// a Bakong Open API Bearer Token, which you only get after registering
/// (free) at https://bakong.nbc.gov.kh and requesting API access. Until
/// then, "I've Completed the Payment" simulates confirmation — exactly
/// like the existing ABA/ACLEDA demo flow.
///
/// TODO once you have a real Bakong account: replace [_bakongAccountId]
/// below with your own registered Bakong account ID (e.g. "you@aclb").
class BakongPaymentScreen extends StatefulWidget {
  final double amount;
  final String orderRef;

  const BakongPaymentScreen({
    super.key,
    required this.amount,
    required this.orderRef,
  });

  @override
  State<BakongPaymentScreen> createState() => _BakongPaymentScreenState();
}

class _BakongPaymentScreenState extends State<BakongPaymentScreen> {
  // TODO: replace with your real Bakong account ID after registering at
  // https://bakong.nbc.gov.kh (free) — e.g. "yourname@wing" / "you@aclb".
  static const _bakongAccountId = 'demo_shopease@devb';
  static const _merchantName = 'ShopEase';

  static const Color primary = Color(0xFF1F6FEB);
  static const Color bakongRed = Color(0xFFE21E26);

  int _seconds = 300; // 5 minutes
  bool _processing = false;
  late final String _khqrPayload;

  @override
  void initState() {
    super.initState();
    _khqrPayload = KhqrGenerator.generate(
      bakongAccountId: _bakongAccountId,
      merchantName: _merchantName,
      amount: widget.amount,
      currency: 'USD',
      billNumber: widget.orderRef,
    );
    _startCountdown();
  }

  void _startCountdown() async {
    while (mounted && _seconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) _seconds--;
      });
    }
  }

  String get _timerText {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _confirmPayment() async {
    if (_seconds <= 0) {
      _snack("⏰ Payment session has expired", Colors.red);
      return;
    }
    if (_processing) return;

    setState(() => _processing = true);

    // Simulated confirmation — see the class doc comment for what a real
    // Bakong verification call (check_transaction_by_md5) would need.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.pop(context, true); // true = payment success
  }

  @override
  Widget build(BuildContext context) {
    final expired = _seconds <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Bakong KHQR"),
        backgroundColor: bakongRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: expired ? Colors.red.shade50 : bakongRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                expired ? "Session expired" : "Expires in $_timerText",
                style: TextStyle(
                  color: expired ? Colors.red : bakongRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, color: bakongRed),
                    const SizedBox(width: 6),
                    const Text("KHQR",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: expired ? 0.3 : 1,
                  child: QrImageView(
                    data: _khqrPayload,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text("\$${widget.amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Order Ref: ${widget.orderRef}",
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
                    "Scan with any Bakong-supported banking app "
                    "(ABA, ACLEDA, Wing, etc.) using the KHQR standard. "
                    "This is a demo payload — live payments require a "
                    "registered Bakong merchant account.",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (expired || _processing) ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: bakongRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _processing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("I've Completed the Payment",
                      style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
}
