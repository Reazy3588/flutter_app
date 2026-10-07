import '../../services/shop_session.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ បន្ថែមសម្រាប់ shop_slug
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../home/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final ShopTheme? shopTheme;
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.shopTheme,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _authService = AuthService();
  String _code = "";
  bool _loading = false;
  bool _resending = false;

  Color get _primary =>
      widget.shopTheme?.primaryColor ?? const Color(0xFF1F6FEB);
  Color get _logoOuterRing =>
      widget.shopTheme?.primaryColor.withOpacity(0.2) ??
      const Color(0xFFD6D0F5);

  Future<void> _verify() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter the 6-digit code")));
      return;
    }
    setState(() => _loading = true);
    try {
      final shopSlug = ShopSession.slug;
      print('🔵 Verify OTP shop_slug: $shopSlug');

      final user = await _authService.verifyOtp(
        phoneNumber: widget.phoneNumber,
        code: _code,
        shopSlug: shopSlug, // ✅ បញ្ជូន shop_slug
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone verified! Welcome.")));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: user,
            shopTheme: widget.shopTheme,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _authService.resendOtp(phoneNumber: widget.phoneNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A new OTP code was sent.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          "Verify Phone Number",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // ================= LOGO =================
              Center(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _logoOuterRing,
                    boxShadow: [
                      BoxShadow(
                        color: _logoOuterRing.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: widget.shopTheme?.logoUrl != null &&
                                  widget.shopTheme!.logoUrl!.isNotEmpty
                              ? Image.network(
                                  widget.shopTheme!.logoUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/rhd_logo.jpeg',
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/rhd_logo.jpeg',
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ================= TITLE =================
              const Text(
                "OTP Verification",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We sent a 6-digit code to\n${widget.phoneNumber}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Check the Django server terminal/console for the code while testing.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ================= PIN CODE FIELD =================
              PinCodeTextField(
                appContext: context,
                length: 6,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(14),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeColor: _primary,
                  selectedColor: _primary,
                  inactiveColor: Colors.grey.shade300,
                  activeFillColor: Colors.white,
                  selectedFillColor: Colors.white,
                  inactiveFillColor: const Color(0xFFF7F8FA),
                ),
                cursorColor: _primary,
                enableActiveFill: true,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                onChanged: (value) => _code = value,
                onCompleted: (value) => _code = value,
              ),
              const SizedBox(height: 32),

              // ================= VERIFY BUTTON =================
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Verify",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // ================= RESEND =================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: _resending ? null : _resend,
                    child: Text(
                      _resending ? "Resending..." : "Resend",
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
