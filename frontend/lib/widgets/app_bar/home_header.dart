import 'package:flutter/material.dart';

/// Greeting header: avatar + "Hello, Name 👋" + shop name
class HomeHeader extends StatelessWidget {
  final String? userName;
  final String? shopName;
  final String? photoUrl;
  final Color primary;
  final VoidCallback? onAvatarTap;

  const HomeHeader({
    super.key,
    this.userName,
    this.shopName,
    this.photoUrl,
    this.primary = const Color(0xFF1F6FEB),
    this.onAvatarTap,
  });

  bool get _hasPhoto => photoUrl != null && photoUrl!.startsWith('http');

  String get _firstName {
    final n = (userName ?? '').trim();
    if (n.isEmpty) return '';
    return n.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final initial = _firstName.isNotEmpty
        ? _firstName[0].toUpperCase()
        : ((shopName ?? 'S').isNotEmpty ? shopName![0].toUpperCase() : 'S');

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: _hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: _hasPhoto
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _firstName.isEmpty ? 'Welcome 👋' : 'Hello, $_firstName 👋',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 1),
              Text(
                (shopName == null || shopName!.isEmpty)
                    ? 'Discover products'
                    : shopName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
