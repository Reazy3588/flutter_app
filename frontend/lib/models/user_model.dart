class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String address;
  final String? profilePhoto;
  final bool isPhoneVerified;
  final bool isStaff;
  final bool isShopOwner;
  final String? shopSlug;
  final String? shopName;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    this.profilePhoto,
    required this.isPhoneVerified,
    this.isStaff = false,
    this.isShopOwner = false,
    this.shopSlug,
    this.shopName,
    this.role = 'customer',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      profilePhoto: json['profile_photo'],
      isPhoneVerified: json['is_phone_verified'] ?? false,
      isStaff: json['is_staff'] ?? false,
      isShopOwner: json['is_shop_owner'] ?? false,
      shopSlug: json['shop_slug'],
      shopName: json['shop_name'],
      role: json['role'] ?? 'customer',
    );
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'address': address,
        'profile_photo': profilePhoto,
        'is_phone_verified': isPhoneVerified,
        'is_staff': isStaff,
        'is_shop_owner': isShopOwner,
        'role': role,
      };
}
