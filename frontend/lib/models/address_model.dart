class AddressModel {
  final int id;
  final String label;
  final String fullName;
  final String phoneNumber;
  final String addressLine;
  final String city;
  final bool isDefault;
  final double? latitude; // ✅ បន្ថែម GPS
  final double? longitude; // ✅ បន្ថែម GPS

  AddressModel({
    required this.id,
    this.label = '',
    required this.fullName,
    required this.phoneNumber,
    required this.addressLine,
    required this.city,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      label: json['label'] ?? '',
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      addressLine: json['address_line'] ?? '',
      city: json['city'] ?? 'Phnom Penh',
      isDefault: json['is_default'] ?? false,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'address_line': addressLine,
        'city': city,
        'is_default': isDefault,
        // ✅ កាត់ត្រឹម 7 ខ្ទង់ទសភាគ
        if (latitude != null)
          'latitude': double.parse(latitude!.toStringAsFixed(7)),
        if (longitude != null)
          'longitude': double.parse(longitude!.toStringAsFixed(7)),
      };
}
