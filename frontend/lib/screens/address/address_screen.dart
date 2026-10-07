import 'package:flutter/material.dart';

import '../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../services/api_service.dart';
import 'address_form_screen.dart';
import 'map_picker_screen.dart';

/// Shipping Addresses
///
/// Features:
/// - Show all saved addresses
/// - Add address
/// - Pick location from map before adding
/// - Edit address
/// - Delete address
/// - Show default address
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final AddressService _service = AddressService();

  List<AddressModel> _addresses = [];
  bool _loading = true;

  static const Color primary = Color(0xFF1F6FEB);
  static const Color background = Color(0xFFF6F8FB);

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  // ============================================================
  // LOAD ADDRESSES
  // ============================================================

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _service.getAddresses();

      if (!mounted) return;

      setState(() {
        _addresses = addresses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ ${extractErrorMessage(e)}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // DELETE ADDRESS
  // ============================================================

  Future<void> _deleteAddress(AddressModel address) async {
    final String displayName =
        address.label.isNotEmpty ? address.label : address.fullName;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Address',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$displayName"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteAddress(address.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Address deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadAddresses();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ ${extractErrorMessage(e)}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // OPEN ADDRESS FORM
  // ============================================================

  Future<void> _openForm({
    AddressModel? address,
  }) async {
    Map<String, dynamic>? pickedLocation;

    // ADD ADDRESS
    //
    // When creating a new address:
    // Map -> Pick location -> Address Form
    if (address == null) {
      pickedLocation = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => const MapPickerScreen(),
        ),
      );

      if (!mounted || pickedLocation == null) {
        return;
      }
    }

    // EDIT / ADD FORM
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(
          address: address,
          pickedLocation: pickedLocation,
        ),
      ),
    );

    if (!mounted) return;

    await _loadAddresses();
  }

  // ============================================================
  // ADDRESS TITLE
  // ============================================================

  String _getAddressTitle(AddressModel address) {
    if (address.label.trim().isNotEmpty) {
      return '${address.label} • ${address.fullName}';
    }

    return address.fullName;
  }

  // ============================================================
  // ADDRESS DETAILS
  // ============================================================

  String _getAddressDetails(AddressModel address) {
    final List<String> parts = [];

    if (address.phoneNumber.trim().isNotEmpty) {
      parts.add(address.phoneNumber);
    }

    if (address.addressLine.trim().isNotEmpty) {
      parts.add(address.addressLine);
    }

    if (address.city.trim().isNotEmpty) {
      parts.add(address.city);
    }

    return parts.join(' • ');
  }

  // ============================================================
  // DEFAULT BADGE
  // ============================================================

  Widget _defaultBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'DEFAULT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================

  Widget _buildAddressCard(AddressModel address) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // LOCATION ICON
            // ==================================================

            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: primary,
                size: 27,
              ),
            ),

            const SizedBox(width: 14),

            // ==================================================
            // ADDRESS INFORMATION
            // ==================================================

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE + DEFAULT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _getAddressTitle(address),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        _defaultBadge(),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // PHONE
                  if (address.phoneNumber.trim().isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address.phoneNumber,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 5),

                  // ADDRESS
                  if (address.addressLine.trim().isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.home_outlined,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [
                              address.addressLine,
                              if (address.city.trim().isNotEmpty) address.city,
                            ].join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // ACTION BUTTONS
                  // ==================================================

                  Row(
                    children: [
                      _actionButton(
                        icon: Icons.edit_outlined,
                        text: 'Edit',
                        color: primary,
                        onPressed: () {
                          _openForm(address: address);
                        },
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: Icons.delete_outline,
                        text: 'Delete',
                        color: Colors.red,
                        onPressed: () {
                          _deleteAddress(address);
                        },
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

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _actionButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_outlined,
                size: 48,
                color: primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No addresses yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your shipping address to make checkout faster and easier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                _openForm();
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Address'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Shipping Addresses',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // ADD BUTTON
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 5,
        onPressed: () {
          _openForm();
        },
        icon: const Icon(
          Icons.add_location_alt_outlined,
        ),
        label: const Text(
          'Add Address',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            )
          : _addresses.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: primary,
                  onRefresh: _loadAddresses,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      110,
                    ),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, __) {
                      return const SizedBox(height: 14);
                    },
                    itemBuilder: (context, index) {
                      final address = _addresses[index];

                      return _buildAddressCard(address);
                    },
                  ),
                ),
    );
  }
}
