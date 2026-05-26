import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/discover_profile.dart';
import '../../models/profile_model.dart';
import '../../utils/compatibility_questions.dart';
import '../../utils/time_utils.dart';
import '../../widgets/compatibility_section.dart';

/// Shows how the current user's profile appears to others in discovery.
/// Read-only — no like/pass actions.
class ProfilePreviewScreen extends StatelessWidget {
  final ProfileModel profile;
  const ProfilePreviewScreen({super.key, required this.profile});

  DiscoverProfile _toDiscoverProfile() => DiscoverProfile(
        userId: profile.userId,
        name: profile.name ?? 'You',
        age: profile.age,
        city: profile.city,
        bio: profile.bio,
        mainPhotoUrl: profile.mainPhotoUrl,
        photoUrls: profile.photoUrls,
        education: profile.education,
        religion: profile.religion,
        relationshipGoal: profile.relationshipGoal,
        hobbies: profile.hobbies,
        vibes: profile.vibes,
        isVerified: profile.isVerified,
        compatibilityAnswers: profile.compatibilityAnswers,
      );

  @override
  Widget build(BuildContext context) {
    final p = _toDiscoverProfile();
    final displayPhoto = p.displayPhoto;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Photo header ──
              SliverAppBar(
                expandedHeight: 420,
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 16),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      displayPhoto != null
                          ? CachedNetworkImage(
                              imageUrl: displayPhoto,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _PlaceholderAvatar(name: p.name),
                            )
                          : _PlaceholderAvatar(name: p.name),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Name overlay
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    p.age != null
                                        ? '${p.name}, ${p.age}'
                                        : p.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (p.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified,
                                      color: Color(0xFF60A5FA), size: 20),
                                ],
                              ],
                            ),
                            if (p.city != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 14, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(p.city!,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Preview banner ──
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFBCFE8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 16, color: Color(0xFFEC4899)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This is how your profile appears to others',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEC4899),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (p.education != null)
                            _InfoChip(Icons.school_outlined, p.education!),
                          if (p.religion != null)
                            _InfoChip(
                                Icons.temple_hindu_outlined, p.religion!),
                          if (p.relationshipGoal != null)
                            _InfoChip(Icons.favorite_border,
                                formatRelationshipGoal(p.relationshipGoal!)),
                        ],
                      ),

                      // Bio
                      if (p.bio != null && p.bio!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'About',
                          child: Text(p.bio!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF374151),
                                  height: 1.6)),
                        ),
                      ],

                      // Hobbies
                      if (p.hobbies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Hobbies',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: p.hobbies
                                .map((h) => _Pill(h, pink: false))
                                .toList(),
                          ),
                        ),
                      ],

                      // Vibes
                      if (p.vibes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Vibe',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: p.vibes
                                .map((v) => _Pill(v, pink: true))
                                .toList(),
                          ),
                        ),
                      ],

                      // More photos
                      if (p.photoUrls.length > 1) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Photos',
                          child: SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: p.photoUrls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: p.photoUrls[i],
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Compatibility Q&A
                      if (p.compatibilityAnswers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        CompatibilitySection(
                          answers: p.compatibilityAnswers,
                          title: compatibilitySectionTitle(p.relationshipGoal),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub widgets ──

class _PlaceholderAvatar extends StatelessWidget {
  final String name;
  const _PlaceholderAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
          ),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white54),
          ),
        ),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFEC4899)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final bool pink;
  const _Pill(this.text, {required this.pink});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: pink
              ? const Color(0xFFFDF2F8)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: pink
                  ? const Color(0xFFFBCFE8)
                  : const Color(0xFFE5E7EB)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                color: pink
                    ? const Color(0xFFEC4899)
                    : const Color(0xFF374151))),
      );
}
