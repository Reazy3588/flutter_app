import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart'; // ✅ បន្ថែមនេះ
import '../home/home_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String phoneNumber;
  final String? debugOtpCode;
  final ShopTheme? shopTheme; // ✅ បន្ថែមនេះ

  const ResetPasswordScreen({
    super.key,
    required this.phoneNumber,
    this.debugOtpCode,
    this.shopTheme,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _newPasswordCtrl = TextEditingController();
  final _newPassword2Ctrl = TextEditingController();

  String _code = "";
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;
  bool _resending = false;

  Color get _primary =>
      widget.shopTheme?.primaryColor ?? const Color(0xFF1F6FEB);
  Color get _logoOuterRing =>
      widget.shopTheme?.primaryColor.withOpacity(0.2) ??
      const Color(0xFFD6D0F5);

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _newPassword2Ctrl.dispose();
    super.dispose();
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_code.length != 6) {
      _snack("Enter the 6-digit code", Colors.orange.shade700);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = await _authService.resetPassword(
        phoneNumber: widget.phoneNumber,
        code: _code,
        newPassword: _newPasswordCtrl.text,
        newPassword2: _newPassword2Ctrl.text,
      );
      if (!mounted) return;
      _snack("Password reset! Welcome back.", Colors.green.shade600);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: user,
            shopTheme: widget.shopTheme, // ✅ បន្ថែមនេះ
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _snack(extractErrorMessage(e), Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _authService.requestPasswordReset(phoneNumber: widget.phoneNumber);
      if (!mounted) return;
      _snack("A new reset code was sent.", Colors.green.shade600);
    } catch (e) {
      if (!mounted) return;
      _snack(extractErrorMessage(e), Colors.red.shade600);
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
          "Reset Password",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
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
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
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
                const SizedBox(height: 20),
                Text(
                  "We sent a 6-digit code to\n${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                if (widget.debugOtpCode != null) ...[
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
                            "Debug code: ${widget.debugOtpCode}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(14),
                    fieldHeight: 52,
                    fieldWidth: 44,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  onChanged: (value) => _code = value,
                  onCompleted: (value) => _code = value,
                ),
                const SizedBox(height: 24),
                _buildPasswordField(
                  controller: _newPasswordCtrl,
                  label: "New Password",
                  obscure: _obscure1,
                  onToggle: () => setState(() => _obscure1 = !_obscure1),
                  validator: (v) => (v == null || v.length < 6)
                      ? "At least 6 characters"
                      : null,
                ),
                const SizedBox(height: 18),
                _buildPasswordField(
                  controller: _newPassword2Ctrl,
                  label: "Confirm New Password",
                  obscure: _obscure2,
                  onToggle: () => setState(() => _obscure2 = !_obscure2),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return "Please confirm your password";
                    if (v != _newPasswordCtrl.text)
                      return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
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
                            "Reset Password",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: _primary, size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey.shade500,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
