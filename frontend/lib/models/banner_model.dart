class BannerModel {
  final int id;
  final String title;
  final String subtitle;
  final String badgeText;
  final String buttonText;
  final String? image;

  /// 'none' | 'category' | 'product'
  final String linkType;

  /// category slug ឬ product slug
  final String linkValue;

  BannerModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.badgeText = '',
    this.buttonText = 'Shop Now',
    this.image,
    this.linkType = 'none',
    this.linkValue = '',
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      badgeText: json['badge_text'] ?? '',
      buttonText: (json['button_text'] ?? '').toString().isEmpty
          ? 'Shop Now'
          : json['button_text'],
      image: json['image'],
      linkType: json['link_type'] ?? 'none',
      linkValue: json['link_value'] ?? '',
    );
  }
}
