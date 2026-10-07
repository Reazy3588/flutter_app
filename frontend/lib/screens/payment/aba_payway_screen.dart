import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';

class AbaPaywayScreen extends StatefulWidget {
  final double amount;
  final String orderRef;
  final String initialBank;

  const AbaPaywayScreen({
    super.key,
    required this.amount,
    required this.orderRef,
    this.initialBank = 'aba',
  });

  @override
  State<AbaPaywayScreen> createState() => _AbaPaywayScreenState();
}

class _AbaPaywayScreenState extends State<AbaPaywayScreen> {
  final _orderService = OrderService();

  // ✅ ទុក QR image ជា bytes ដើម្បីបង្ហាញរូបភាព KHQR ផ្លូវការពី ABA
  Uint8List? _qrImageBytes;
  bool _loadingQr = true;
  bool _checking = false;
  String? _error;
  int _seconds = 300;

  // ✅ Auto-Check Timer
  Timer? _autoCheckTimer;
  bool _paymentConfirmed = false;

  static const Color primary = Color(0xFF1F6FEB);

  @override
  void initState() {
    super.initState();
    _generateQr();
    _startCountdown();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel(); // ✅ បញ្ឈប់ Timer ពេលចាកចេញ
    super.dispose();
  }

  Future<void> _generateQr() async {
    setState(() {
      _loadingQr = true;
      _error = null;
    });
    try {
      final res = await _orderService.generateAbaQr(
        amount: widget.amount,
        tranId: widget.orderRef,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        // ✅ qr_image មកជា data URI: "data:image/png;base64,XXXXX"
        final qrImageData = res['qr_image'] as String?;
        Uint8List? bytes;
        if (qrImageData != null && qrImageData.isNotEmpty) {
          final base64Part = qrImageData.contains(',')
              ? qrImageData.split(',').last
              : qrImageData;
          bytes = base64Decode(base64Part);
        }
        setState(() {
          _qrImageBytes = bytes;
          _loadingQr = false;
        });

        // ✅ ចាប់ផ្តើម Auto-Check បន្ទាប់ពី QR ត្រូវបានបង្កើត
        _startAutoCheck();
      } else {
        setState(() {
          _error = res['error'] ?? 'Failed to generate QR';
          _loadingQr = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractErrorMessage(e);
        _loadingQr = false;
      });
    }
  }

  void _startCountdown() async {
    while (mounted && _seconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds--);
    }
  }

  // ✅ ចាប់ផ្តើម Auto-Check រាល់ ៥ វិនាទី
  void _startAutoCheck() {
    _autoCheckTimer?.cancel(); // បញ្ឈប់ Timer ចាស់ (បើមាន)
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted &&
          _qrImageBytes != null &&
          _seconds > 0 &&
          !_paymentConfirmed) {
        _autoCheckPayment();
      }
    });
  }

  // ✅ Auto-Check Payment Status
  Future<void> _autoCheckPayment() async {
    if (_paymentConfirmed) return;
    try {
      final res = await _orderService.checkAbaTransaction(widget.orderRef);
      if (!mounted) return;
      if (res['is_paid'] == true) {
        _paymentConfirmed = true;
        _autoCheckTimer?.cancel();
        // ✅ Auto Redirect ទៅ Checkout → បង្កើត Order → Receipt
        Navigator.pop(context, true);
      }
    } catch (_) {
      // មិនបង្ហាញ Error ពេល Auto-Check (ព្រោះវារត់រាល់ ៥ វិនាទី)
    }
  }

  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // ✅ Manual Check (ប៊ូតុង "I've Paid")
  Future<void> _checkPayment() async {
    setState(() => _checking = true);
    try {
      final res = await _orderService.checkAbaTransaction(widget.orderRef);
      if (!mounted) return;
      if (res['is_paid'] == true) {
        _paymentConfirmed = true;
        _autoCheckTimer?.cancel();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "⏳ Payment not yet confirmed. Please complete payment first."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ ${extractErrorMessage(e)}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("ABA PayWay"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Timer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _seconds <= 60
                    ? Colors.red.shade50
                    : primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _seconds <= 0 ? "Session expired" : "Expires in $_timerText",
                  style: TextStyle(
                    color: _seconds <= 60 ? Colors.red : primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ✅ Auto-Check Status Indicator
            if (_paymentConfirmed)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Payment confirmed! Redirecting...',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // QR Container — បង្ហាញ qr_image (Official ABA KHQR image)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _loadingQr
                      ? const SizedBox(
                          height: 240,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _error != null
                          ? SizedBox(
                              height: 380,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 48),
                                  const SizedBox(height: 10),
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style:
                                          const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: _generateQr,
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            )
                          : _qrImageBytes == null
                              ? const SizedBox(
                                  height: 240,
                                  child: Center(
                                      child: Text("No QR image received")),
                                )
                              : Opacity(
                                  opacity: _seconds <= 0 ? 0.3 : 1,
                                  child: Image.memory(
                                    _qrImageBytes!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    filterQuality: FilterQuality.high,
                                    isAntiAlias: true,
                                  ),
                                ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Scan this QR with any bank app that supports KHQR",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),

            const SizedBox(height: 12),

            // ✅ Auto-check hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto-checking every 5 seconds...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Check Payment Button (Manual)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: (_checking ||
                        _qrImageBytes == null ||
                        _seconds <= 0 ||
                        _paymentConfirmed)
                    ? null
                    : _checkPayment,
                icon: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _checking ? "Checking..." : "I've Paid - Check Now",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _paymentConfirmed
                  ? null
                  : () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }
}
