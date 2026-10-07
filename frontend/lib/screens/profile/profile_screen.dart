import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../address/address_screen.dart';
import '../orders/my_orders_screen.dart';
import '../admin/delivery_orders_screen.dart';
import '../shop_admin/shop_admin_dashboard.dart';
import '../shop/shop_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late UserModel _user;
  bool _saving = false;
  bool _loading = true;
  bool _isEditing = false;

  late TextEditingController _fullNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;

  Uint8List? _pickedPhotoBytes;
  String? _pickedPhotoName;

  static const Color primary = Color(0xFF1F6FEB);
  static const Color bgColor = Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _fullNameCtrl = TextEditingController(text: _user.fullName)
      ..addListener(_onChanged);
    _emailCtrl = TextEditingController(text: _user.email)
      ..addListener(_onChanged);
    _phoneCtrl = TextEditingController(text: _user.phoneNumber)
      ..addListener(_onChanged);
    _addressCtrl = TextEditingController(text: _user.address)
      ..addListener(_onChanged);
    _refreshProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _hasChanges {
    return _pickedPhotoBytes != null ||
        _fullNameCtrl.text.trim() != _user.fullName ||
        _emailCtrl.text.trim() != _user.email ||
        _phoneCtrl.text.trim() != _user.phoneNumber ||
        _addressCtrl.text.trim() != _user.address;
  }

  Future<void> _refreshProfile() async {
    try {
      final fresh = await _authService.getProfile();
      if (!mounted) return;
      setState(() {
        _user = fresh;
        _fullNameCtrl.text = fresh.fullName;
        _emailCtrl.text = fresh.email;
        _phoneCtrl.text = fresh.phoneNumber;
        _addressCtrl.text = fresh.address;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (!_isEditing) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedPhotoBytes = bytes;
      _pickedPhotoName = picked.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await _authService.updateProfile(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        photoBytes: _pickedPhotoBytes,
        photoFilename: _pickedPhotoName,
      );
      if (!mounted) return;
      setState(() {
        _user = updated;
        _pickedPhotoBytes = null;
        _pickedPhotoName = null;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(extractErrorMessage(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _pickedPhotoBytes = null;
      _pickedPhotoName = null;
      _fullNameCtrl.text = _user.fullName;
      _emailCtrl.text = _user.email;
      _phoneCtrl.text = _user.phoneNumber;
      _addressCtrl.text = _user.address;
    });
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  ImageProvider? _avatarImage() {
    if (_pickedPhotoBytes != null) return MemoryImage(_pickedPhotoBytes!);
    if (_user.profilePhoto != null && _user.profilePhoto!.isNotEmpty) {
      return NetworkImage(_user.profilePhoto!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: primary,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // ===== MODERN HEADER =====
              SliverToBoxAdapter(child: _buildModernHeader()),

              // ===== BODY =====
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),

                    // ===== STATS ROW =====
                    _buildStatsRow(),
                    const SizedBox(height: 24),

                    // ===== PERSONAL INFO =====
                    _buildSectionHeader(
                      title: "Personal Information",
                      icon: Icons.person_outline,
                      trailing: _isEditing ? null : _buildEditButton(),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoList(),

                    // ===== ACTION BUTTONS =====
                    if (_isEditing) ...[
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                    ],

                    const SizedBox(height: 28),

                    // ===== SHOP ADMIN PANEL =====
                    if (_user.isShopOwner) ...[
                      _buildSectionHeader(
                        title: "Shop Management",
                        icon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildShopAdminCard(),
                      const SizedBox(height: 28),
                    ],

                    // ===== QUICK LINKS =====
                    _buildSectionHeader(
                      title: "Quick Links",
                      icon: Icons.grid_view_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildQuickActionsGrid(),

                    // ===== STAFF DASHBOARD =====
                    if (_user.isStaff) ...[
                      const SizedBox(height: 10),
                      _buildQuickLink(
                        icon: Icons.local_shipping_outlined,
                        label: "Delivery Dashboard",
                        subtitle: "Staff only",
                        color: Colors.deepOrange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DeliveryOrdersScreen()),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ===== LOGOUT =====
                    _buildLogoutButton(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= MODERN HEADER =================
  // ================= MODERN HEADER =================
  Widget _buildModernHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F8EF7), Color(0xFF1F6FEB), Color(0xFF1547A8)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main Content Column
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 118,
                    height: 118,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFE0E7FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _avatarImage(),
                      child: _avatarImage() == null
                          ? const Icon(Icons.person,
                              size: 52, color: Colors.grey)
                          : null,
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 18, color: primary),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                _user.fullName.isNotEmpty ? _user.fullName : _user.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              // Username
              Text(
                "@${_user.username}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              // Badges Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (_user.isPhoneVerified)
                    _buildHeaderBadge(
                      icon: Icons.verified,
                      label: "Phone Verified",
                      color: Colors.greenAccent,
                    ),
                  if (_user.isShopOwner)
                    _buildHeaderBadge(
                      icon: Icons.store,
                      label: "Shop Owner",
                      color: Colors.amber,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================= STATS ROW =================
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.shopping_bag_outlined,
            label: "Orders",
            value: "—",
            color: primary,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.favorite_outline,
            label: "Wishlist",
            value: "—",
            color: Colors.redAccent,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.star_outline,
            label: "Reviews",
            value: "—",
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade200,
    );
  }

  // ================= SECTION HEADER =================
  Widget _buildSectionHeader({
    required String title,
    IconData? icon,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildEditButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isEditing = true),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 15, color: primary),
              const SizedBox(width: 4),
              Text(
                "Edit",
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= ACTION BUTTONS (Cancel/Save) =================
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : _cancelEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              "Cancel",
              style: TextStyle(
                  color: Colors.grey.shade700, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_saving || !_hasChanges) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    "Save Changes",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  // ================= SHOP ADMIN CARD =================
  Widget _buildShopAdminCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.storefront, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Shop Admin Panel",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Manage your shop, products & orders",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildShopActionButton(
                  icon: Icons.dashboard,
                  label: "Dashboard",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShopAdminDashboard()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildShopActionButton(
                  icon: Icons.palette,
                  label: "Theme",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShopSettingsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= INFO LIST =================
  Widget _buildInfoList() {
    return Column(
      children: [
        _buildInfoTile(
          label: "Full Name",
          value: _user.fullName,
          controller: _fullNameCtrl,
          icon: Icons.person_outline,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? "Full name is required" : null,
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          label: "Email",
          value: _user.email,
          controller: _emailCtrl,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return "Email is required";
            if (!v.contains('@')) return "Enter a valid email";
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          label: "Phone Number",
          value: _user.phoneNumber,
          controller: _phoneCtrl,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? "Phone number is required"
              : null,
        ),
        const SizedBox(height: 12),
        _buildInfoTile(
          label: "Address",
          value: _user.address,
          controller: _addressCtrl,
          icon: Icons.location_on_outlined,
          maxLines: 1,
        ),
      ],
    );
  }

  // ================= INFO TILE =================
  Widget _buildInfoTile({
    required String label,
    required String value,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            prefixIcon: Icon(icon, color: primary, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.15),
                  primary.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : "—",
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= QUICK ACTIONS GRID =================
  Widget _buildQuickActionsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.receipt_long,
            label: "My Orders",
            color: primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.location_on_outlined,
            label: "Addresses",
            color: Colors.deepOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    "View",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios,
                      size: 10, color: Colors.grey.shade500),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= QUICK LINK =================
  Widget _buildQuickLink({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ================= LOGOUT BUTTON =================
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout, color: Colors.red, size: 20),
        label: const Text(
          "Logout",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.05),
          side: BorderSide(color: Colors.red.shade200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
