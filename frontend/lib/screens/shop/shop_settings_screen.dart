import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/shop_service.dart';
import '../../services/api_service.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopService = ShopService();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  Color _primaryColor = const Color(0xFF1F6FEB);
  Color _secondaryColor = const Color(0xFF1547A8);
  Color _accentColor = const Color(0xFF00D2FF);

  Uint8List? _pickedLogoBytes;
  String? _pickedLogoName;
  String? _currentLogoUrl;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShop() async {
    try {
      final shop = await _shopService.getMyShop();
      setState(() {
        _nameCtrl.text = shop['name'] ?? '';
        _descriptionCtrl.text = shop['description'] ?? '';
        _phoneCtrl.text = shop['phone'] ?? '';
        _emailCtrl.text = shop['email'] ?? '';
        _primaryColor = _hexToColor(shop['primary_color'] ?? '#1F6FEB');
        _secondaryColor = _hexToColor(shop['secondary_color'] ?? '#1547A8');
        _accentColor = _hexToColor(shop['accent_color'] ?? '#00D2FF');
        _currentLogoUrl = shop['logo'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(extractErrorMessage(e), Colors.red);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedLogoBytes = bytes;
      _pickedLogoName = picked.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await _shopService.updateMyShop(
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        primaryColor: _colorToHex(_primaryColor),
        secondaryColor: _colorToHex(_secondaryColor),
        accentColor: _colorToHex(_accentColor),
        logoBytes: _pickedLogoBytes,
        logoFilename: _pickedLogoName,
      );

      if (!mounted) return;
      _snack('✅ Shop updated successfully!', Colors.green);
      setState(() {
        _pickedLogoBytes = null;
        _pickedLogoName = null;
      });
    } catch (e) {
      if (!mounted) return;
      _snack('❌ ${extractErrorMessage(e)}', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("Shop Settings"),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Shop Logo"),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: _primaryColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _pickedLogoBytes != null
                              ? Image.memory(_pickedLogoBytes!,
                                  fit: BoxFit.cover)
                              : (_currentLogoUrl != null
                                  ? Image.network(_currentLogoUrl!,
                                      fit: BoxFit.cover)
                                  : Icon(Icons.store,
                                      size: 60, color: _primaryColor)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _sectionTitle("Shop Information"),
              const SizedBox(height: 12),
              _buildCard([
                _buildField(
                  label: "Shop Name",
                  controller: _nameCtrl,
                  icon: Icons.store_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Shop name is required"
                      : null,
                ),
                const Divider(height: 24),
                _buildField(
                  label: "Description",
                  controller: _descriptionCtrl,
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
                const Divider(height: 24),
                _buildField(
                  label: "Phone",
                  controller: _phoneCtrl,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const Divider(height: 24),
                _buildField(
                  label: "Email",
                  controller: _emailCtrl,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ]),
              const SizedBox(height: 28),
              _sectionTitle("Theme Colors"),
              const SizedBox(height: 12),
              _buildCard([
                _buildColorPicker(
                  label: "Primary Color",
                  color: _primaryColor,
                  onChanged: (c) => setState(() => _primaryColor = c),
                ),
                const Divider(height: 24),
                _buildColorPicker(
                  label: "Secondary Color",
                  color: _secondaryColor,
                  onChanged: (c) => setState(() => _secondaryColor = c),
                ),
                const Divider(height: 24),
                _buildColorPicker(
                  label: "Accent Color",
                  color: _accentColor,
                  onChanged: (c) => setState(() => _accentColor = c),
                ),
              ]),
              const SizedBox(height: 28),
              _sectionTitle("Preview"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameCtrl.text.isEmpty ? 'My Shop' : _nameCtrl.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Preview of your shop theme',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Shop Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: _primaryColor, size: 22),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _buildColorPicker({
    required String label,
    required Color color,
    required ValueChanged<Color> onChanged,
  }) {
    final colors = [
      const Color(0xFF1F6FEB),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFF000000),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final isSelected = c.value == color.value;
            return GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
