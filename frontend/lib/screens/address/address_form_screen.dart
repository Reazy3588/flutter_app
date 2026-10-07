import 'package:flutter/material.dart';
import '../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AddressFormScreen extends StatefulWidget {
  final AddressModel? address; // null = Add | មាន = Edit
  final Map<String, dynamic>? pickedLocation; // 👈 ទិន្នន័យពី map picker

  const AddressFormScreen({
    super.key,
    this.address,
    this.pickedLocation,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AddressService();
  final _authService = AuthService();

  // 👈 controllers
  late final TextEditingController _labelCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;

  late bool _isDefault;
  bool _saving = false;
  bool _loadingUser = true;

  // ✅ GPS Coordinates
  double? _latitude;
  double? _longitude;

  static const Color primary = Color(0xFF1F6FEB);

  bool get _isEdit => widget.address != null;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.address?.label ?? '');
    _nameCtrl = TextEditingController(text: widget.address?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: widget.address?.phoneNumber ?? '');

    // ✅ បំពេញ address/city ពី map
    // បើទំនេរ → ដាក់ Default ដើម្បីកុំឱ្យ Error
    final pickedAddress =
        widget.pickedLocation?['addressLine'] as String? ?? '';
    final pickedCity = widget.pickedLocation?['city'] as String? ?? '';

    _addressCtrl = TextEditingController(
      text: widget.address?.addressLine ??
          (pickedAddress.isNotEmpty ? pickedAddress : 'Selected Location'),
    );
    _cityCtrl = TextEditingController(
      text: widget.address?.city ??
          (pickedCity.isNotEmpty ? pickedCity : 'Unknown City'),
    );
    _isDefault = widget.address?.isDefault ?? false;

    if (widget.pickedLocation != null) {
      _latitude = (widget.pickedLocation!['lat'] as num?)?.toDouble();
      _longitude = (widget.pickedLocation!['lng'] as num?)?.toDouble();
    } else if (widget.address != null) {
      _latitude = widget.address!.latitude;
      _longitude = widget.address!.longitude;
    }

    // ✅ បើ Add Address ថ្មី → ទាញ User Profile ដើម្បី Auto-fill
    if (!_isEdit) {
      _loadUserProfile();
    } else {
      _loadingUser = false;
    }
  }

  /// ✅ ទាញ User Profile ដើម្បីបំពេញ Full Name និង Phone ដោយស្វ័យប្រវត្តិ
  Future<void> _loadUserProfile() async {
    try {
      final user = await _authService.getProfile();
      if (!mounted) return;
      setState(() {
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = user.fullName;
        if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = user.phoneNumber;
        _loadingUser = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // ✅ កាត់ត្រឹម 7 ខ្ទង់ទសភាគ
    double? roundedLat;
    double? roundedLng;
    if (_latitude != null) {
      roundedLat = double.parse(_latitude!.toStringAsFixed(7));
    }
    if (_longitude != null) {
      roundedLng = double.parse(_longitude!.toStringAsFixed(7));
    }

    final address = AddressModel(
      id: widget.address?.id ?? 0,
      label: _labelCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      addressLine: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      isDefault: _isDefault,
      latitude: roundedLat, // ✅ ប្រើតម្លៃកាត់រួច
      longitude: roundedLng, // ✅ ប្រើតម្លៃកាត់រួច
    );

    try {
      if (_isEdit) {
        await _service.updateAddress(widget.address!.id, address);
      } else {
        await _service.createAddress(address);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("✅ Address ${_isEdit ? 'updated' : 'added'}"),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ ${extractErrorMessage(e)}"),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? "Edit Address" : "New Address",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---------- Location selected banner ----------
                  if (widget.pickedLocation != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary.withOpacity(0.12),
                            primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: primary, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Location auto-filled from map",
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ---------- Label ----------
                  _buildField(
                    _labelCtrl,
                    "Label (e.g. Home, Office)",
                    Icons.label_outline,
                    hintText: "Home",
                  ),

                  const SizedBox(height: 16),

                  // ---------- Section Header: Contact Info ----------
                  _sectionHeader("Contact Information"),
                  const SizedBox(height: 10),

                  // ---------- Full Name (Auto-filled, read-only) ----------
                  _buildReadOnlyField(
                    _nameCtrl,
                    "Full Name",
                    Icons.person_outline,
                  ),

                  const SizedBox(height: 14),

                  // ---------- Phone (Auto-filled, read-only) ----------
                  _buildReadOnlyField(
                    _phoneCtrl,
                    "Phone Number",
                    Icons.phone_outlined,
                  ),

                  const SizedBox(height: 16),

                  // ---------- Section Header: Address ----------
                  _sectionHeader("Address Details"),
                  const SizedBox(height: 10),

                  // ---------- Street Address (Auto-filled) ----------
                  _buildField(
                    _addressCtrl,
                    "Street Address",
                    Icons.home_outlined,
                    maxLines: 2,
                    hintText: "Auto-filled from map",
                    readOnly: true,
                  ),

                  const SizedBox(height: 14),

                  // ---------- City (Auto-filled) ----------
                  _buildField(
                    _cityCtrl,
                    "City",
                    Icons.location_city_outlined,
                    hintText: "Auto-filled from map",
                    readOnly: true,
                  ),

                  const SizedBox(height: 8),

                  // ---------- Default Switch ----------
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SwitchListTile(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      activeColor: primary,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Set as default address",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        "Used automatically at checkout",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ---------- Save Button ----------
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Save Address",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------- Section Header ----------
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ---------- Editable Field ----------
  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hintText,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? Colors.grey.shade700 : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: primary, size: 22),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: readOnly ? Colors.grey.shade200 : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        suffixIcon: readOnly
            ? Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  // ---------- Read-only Field (with lock icon) ----------
  Widget _buildReadOnlyField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ctrl.text.isNotEmpty ? ctrl.text : "—",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
