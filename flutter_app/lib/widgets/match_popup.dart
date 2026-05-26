import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/match_model.dart';
import '../screens/chat/chat_screen.dart';

/// Full-screen match celebration dialog.
///
/// Usage:
///   showDialog(context: ctx, barrierColor: Colors.black87,
///     builder: (_) => MatchPopup(myPhoto: ..., partnerName: ..., ...));
class MatchPopup extends StatelessWidget {
  final String? myName;
  final String? myPhoto;
  final String partnerName;
  final String? partnerPhoto;
  final String? matchId;
  final String? partnerId;

  const MatchPopup({
    super.key,
    this.myName,
    this.myPhoto,
    required this.partnerName,
    this.partnerPhoto,
    this.matchId,
    this.partnerId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D1A), Color(0xFF1A0A14), Color(0xFF0D0D1A)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60, left: -60,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFEC4899).withOpacity(0.25),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -60, right: -60,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF9333EA).withOpacity(0.20),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💕', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 16),
                  const Text(
                    'CONGRATULATIONS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                    ).createShader(r),
                    child: const Text(
                      "It's a Match!",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You and $partnerName liked each other',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 36),

                  // Photo cards
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(-55, 0),
                          child: Transform.rotate(
                            angle: -0.14,
                            child: _PhotoCard(url: myPhoto, fallbackIcon: Icons.person),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(55, 0),
                          child: Transform.rotate(
                            angle: 0.10,
                            child: _PhotoCard(url: partnerPhoto, fallbackIcon: Icons.person),
                          ),
                        ),
                        Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0x66EC4899),
                                  blurRadius: 12,
                                  spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ),

                  // Names under photos
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            myName ?? 'You',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            partnerName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        // Chat Now
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x55EC4899),
                                    blurRadius: 16,
                                    offset: Offset(0, 6)),
                              ],
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                if (matchId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        match: MatchModel(
                                          matchId: matchId!,
                                          partnerId: partnerId ?? '',
                                          partnerName: partnerName,
                                          partnerPhotoUrl: partnerPhoto,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Chat Now',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Keep swiping
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            child: const Text(
                              'Keep swiping',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  const _PhotoCard({this.url, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 175,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D1B33), Color(0xFF1A0A14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(child: Icon(fallbackIcon, color: Colors.white30, size: 48)),
      );
}
