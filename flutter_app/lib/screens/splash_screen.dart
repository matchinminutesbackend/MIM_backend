import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'auth/intro_screen.dart';
import 'auth/login_screen.dart';
import 'auth/profile_setup_screen.dart';
import 'auth/banned_screen.dart';
import 'auth/under_review_screen.dart';
import 'dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.80, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final results = await Future.wait([
      auth.initialize(),
      ApiService.getPlatformOpen(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;
    final platformOpen = results[1] as bool;
    Widget next;
    if (!platformOpen) {
      next = const UnderReviewScreen();
    } else if (auth.banInfo != null) {
      next = BannedScreen(
        reason: auth.banInfo!.message,
        expiresAt: auth.banInfo!.expiresAtDateTime,
      );
    } else if (!auth.isLoggedIn) {
      next = const IntroScreen();
    } else if (!auth.isProfileComplete) {
      next = const ProfileSetupScreen();
    } else {
      next = const DashboardScreen();
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,          // ← fills the whole screen
        children: [

          // ── Layer 1: gradient background ──────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFDE8F0), // very light pink top
                  Color(0xFFFBD0E4), // soft pink mid
                  Color(0xFFF9A8D4), // pink-300 bottom
                ],
              ),
            ),
          ),

          // ── Layer 2: tiled heart pattern (matches website chat bg) ─
          CustomPaint(
            painter: _HeartPatternPainter(),
          ),

          // ── Layer 3: centre content ───────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // Icon badge — white circle with pink shadow
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withOpacity(0.30),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Image.asset(
                            'assets/images/icon.png',
                            fit: BoxFit.contain,
                            // Reliable fallback: pink heart icon
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFEC4899),
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App name
                    const Text(
                      'MatchInMinutes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9D174D), // pink-800
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Find Your Perfect Match',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFEC4899).withOpacity(0.75),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer 4: "from lazyrabbit.in" pinned bottom ───────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: FadeTransition(
              opacity: _fade,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'from',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBE185D),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'lazyrabbit.in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9D174D),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tiled heart pattern — matches the website chat UI background exactly
class _HeartPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEC4899).withOpacity(0.10)
      ..style = PaintingStyle.fill;

    const double tile = 80.0;
    const double heartSize = 14.0;

    final cols = (size.width  / tile).ceil() + 1;
    final rows = (size.height / tile).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Brick offset: odd rows shifted right by half a tile
        final dx = c * tile + (r.isOdd ? tile / 2 : 0.0);
        final dy = r * tile + tile / 2;
        _drawHeart(canvas, paint, Offset(dx, dy), heartSize);
      }
    }
  }

  void _drawHeart(Canvas canvas, Paint paint, Offset center, double s) {
    // Simple parametric heart scaled to size `s`
    final path = Path();
    final cx = center.dx;
    final cy = center.dy;

    path.moveTo(cx, cy + s * 0.25);
    // left bump
    path.cubicTo(
      cx - s * 0.50, cy,
      cx - s * 0.75, cy - s * 0.50,
      cx,            cy - s * 0.25,
    );
    // right bump
    path.cubicTo(
      cx + s * 0.75, cy - s * 0.50,
      cx + s * 0.50, cy,
      cx,            cy + s * 0.25,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeartPatternPainter _) => false;
}
