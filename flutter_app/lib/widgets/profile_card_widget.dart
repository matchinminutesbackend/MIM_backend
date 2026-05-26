import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/discover_profile.dart';

class ProfileCardWidget extends StatelessWidget {
  final DiscoverProfile profile;
  final bool isTop;

  const ProfileCardWidget({
    super.key,
    required this.profile,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final photo = profile.displayPhoto;

    return Container(
      width: size.width - 32,
      height: size.height * 0.62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isTop
            ? [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 4))]
            : [],
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          photo != null
              ? CachedNetworkImage(
                  imageUrl: photo,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),

          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Info
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (profile.age != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${profile.age}',
                        style: const TextStyle(color: Colors.white70, fontSize: 22),
                      ),
                    ],
                    if (profile.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Color(0xFF4FC3F7), size: 20),
                    ],
                  ],
                ),
                if (profile.city != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white60, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        profile.city!,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
                if (profile.hobbies.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: profile.hobbies.take(4).map((h) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Text(h,
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.person, size: 80, color: Colors.grey),
        ),
      );
}
