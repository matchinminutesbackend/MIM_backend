import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'banned_screen.dart';
import 'under_review_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'profile_setup_screen.dart';
import '../dashboard/dashboard_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  // Profiles data matching the React app
  final List<Map<String, String>> _profiles = const [
    {
      'img': 'assets/images/p1.jpg',
      'name': 'Sofia',
      'age': '24',
      'city': 'Lisbon',
    },
    {
      'img': 'assets/images/p2.jpg',
      'name': 'Liam',
      'age': '27',
      'city': 'Berlin',
    },
    {
      'img': 'assets/images/p3.jpg',
      'name': 'Maya',
      'age': '23',
      'city': 'Paris',
    },
  ];

  int _activeIndex = 0;
  int _swipeDir = 1; // 1 = Like (right), -1 = Nope (left)
  bool _introDone = false;
  Timer? _autoSwipeTimer;
  bool _checkingAuth = true;

  // Animation Controllers
  late final AnimationController _introController;
  late final AnimationController _swipeController;
  late final AnimationController _enterController;
  late final AnimationController _heartPopupController;
  late final AnimationController _pulseController;
  late final AnimationController _logoBounceController;
  late final AnimationController _driftController;

  // Animations
  late final Animation<double> _introProgress;
  late final Animation<double> _logoBounceScale;
  late final Animation<double> _logoBounceRotate;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // 1. Intro Transition Controller (welcome state to main state)
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _introProgress = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeInOutCubic,
    );

    // 2. Card Swipe Controller (fly out exit)
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // 3. Card Enter Controller (fade and scale in)
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0, // start fully entered
    );

    // 4. Large Heart Popup Controller
    _heartPopupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 5. Pulsing Rings Controller (behind logo)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // 6. Logo Bounce Controller
    _logoBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _logoBounceScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _logoBounceController, curve: Curves.easeInOut),
    );
    _logoBounceRotate = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _logoBounceController, curve: Curves.easeInOut),
    );

    // 7. Background Drift Controller
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Start checking authentication
    _initAuth();
  }

  Future<void> _initAuth() async {
    final auth = context.read<AuthProvider>();
    try {
      final results = await Future.wait([
        auth.initialize(),
        ApiService.getPlatformOpen(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);

      if (!mounted) return;

      final platformOpen = results[1] as bool;

      Widget? nextScreen;
      if (!platformOpen) {
        nextScreen = const UnderReviewScreen();
      } else if (auth.banInfo != null) {
        nextScreen = BannedScreen(
          reason: auth.banInfo!.message,
          expiresAt: auth.banInfo!.expiresAtDateTime,
        );
      } else if (auth.isLoggedIn) {
        if (!auth.isProfileComplete) {
          nextScreen = const ProfileSetupScreen();
        } else {
          nextScreen = const DashboardScreen();
        }
      }

      if (nextScreen != null) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => nextScreen!,
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      } else {
        setState(() {
          _checkingAuth = false;
        });
        _introController.forward().then((_) {
          if (mounted) {
            setState(() {
              _introDone = true;
            });
            _startAutoSwipe();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingAuth = false;
        });
        _introController.forward().then((_) {
          if (mounted) {
            setState(() {
              _introDone = true;
            });
            _startAutoSwipe();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _autoSwipeTimer?.cancel();
    _introController.dispose();
    _swipeController.dispose();
    _enterController.dispose();
    _heartPopupController.dispose();
    _pulseController.dispose();
    _logoBounceController.dispose();
    _driftController.dispose();
    super.dispose();
  }

  void _startAutoSwipe() {
    _autoSwipeTimer?.cancel();
    _autoSwipeTimer = Timer.periodic(const Duration(milliseconds: 2600), (timer) {
      if (!mounted) return;
      _triggerSwipe(math.Random().nextBool() ? 1 : -1);
    });
  }

  void _triggerSwipe(int dir) {
    if (_swipeController.isAnimating || _enterController.isAnimating) return;
    _autoSwipeTimer?.cancel(); // temporarily pause timer

    setState(() {
      _swipeDir = dir;
    });

    // If it's a LIKE, play the big heart popup animation in sync
    if (dir == 1) {
      _heartPopupController.forward(from: 0.0);
    }

    // Run the swipe out animation
    _swipeController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      // Change active index
      setState(() {
        _activeIndex = (_activeIndex + 1) % _profiles.length;
      });
      _swipeController.reset();
      _enterController.value = 1.0; // Keep the active card fully entered
      // Restart the auto-swipe timer
      _startAutoSwipe();
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // success
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    // Responsive measurements adjusted to fit standard mobile screen heights
    final cardHeight = (size.height * 0.40).clamp(320.0, 420.0);
    final cardWidth = (size.width * 0.78).clamp(260.0, 300.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Gradient Background ──────────────────────────
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

          // ── Layer 2: Floating Blurred Blobs ───────────────────────
          AnimatedBuilder(
            animation: _driftController,
            builder: (context, child) {
              // Drift keyframe values: translate(0, 0) -> translate(30, -20) -> translate(-20, 20) -> translate(0, 0)
              double t = _driftController.value;
              double dx = 0.0;
              double dy = 0.0;
              if (t < 0.33) {
                double localT = t / 0.33;
                dx = localT * 30.0;
                dy = localT * -20.0;
              } else if (t < 0.66) {
                double localT = (t - 0.33) / 0.33;
                dx = 30.0 + localT * -50.0;
                dy = -20.0 + localT * 40.0;
              } else {
                double localT = (t - 0.66) / 0.34;
                dx = -20.0 + localT * 20.0;
                dy = 20.0 + localT * -20.0;
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Top-left pink blob (bg-primary/30 blur-3xl)
                  Positioned(
                    top: -60 + dy,
                    left: -60 + dx,
                    child: _buildBlurBlob(
                      size: 260,
                      color: const Color(0xFFEC4899).withOpacity(0.20),
                    ),
                  ),
                  // Mid-right orange/accent blob (bg-accent/60 blur-3xl)
                  Positioned(
                    top: size.height * 0.25 - dy,
                    right: -70 - dx,
                    child: _buildBlurBlob(
                      size: 280,
                      color: const Color(0xFFFF9E80).withOpacity(0.25),
                    ),
                  ),
                  // Bottom-left soft pink blob (bg-primary/20 blur-3xl)
                  Positioned(
                    bottom: -30 + dy,
                    left: size.width * 0.2 + dx,
                    child: _buildBlurBlob(
                      size: 250,
                      color: const Color(0xFFF472B6).withOpacity(0.15),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Layer 3: Floating Little Hearts ───────────────────────
          _FloatingLittleHearts(pulseController: _pulseController),

          // ── Layer 4: Primary Content (Logo, Stage, Buttons) ───────
          SafeArea(
            child: AnimatedBuilder(
              animation: _introProgress,
              builder: (context, child) {
                // Layout logic shifting elements depending on whether intro sequence has completed
                // Layout logic shifting elements depending on whether intro sequence has completed
                // Logo initial y: 25vh (0.25 * screenHeight), scale: 1.2
                // Logo final y: 0.0, scale: 1.0
                double logoY = (1.0 - _introProgress.value) * (size.height * 0.25);
                double logoScale = 1.2 - (_introProgress.value * 0.2);
                double otherOpacity = _introProgress.value;

                return Column(
                  children: [
                    const SizedBox(height: 16),
                    // Logo + Brand Header
                    Transform.translate(
                      offset: Offset(0, logoY),
                      child: Transform.scale(
                        scale: logoScale,
                        child: _buildLogoHeader(theme),
                      ),
                    ),

                    // Stage + CTAs (Only shown / faded in when introDone progresses)
                    Expanded(
                      child: IgnorePointer(
                        ignoring: _introProgress.value == 0.0,
                        child: Opacity(
                          opacity: otherOpacity,
                          child: Transform.translate(
                            offset: Offset(0, (1.0 - otherOpacity) * 30),
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 3D Swipe Stage Container
                              SizedBox(
                                height: cardHeight + 40,
                                width: size.width,
                                child: Center(
                                  child: SizedBox(
                                    height: cardHeight + 40,
                                    width: cardWidth,
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        // 1. Back card (Card 3 in Stack)
                                        AnimatedBuilder(
                                          animation: _swipeController,
                                          builder: (context, child) {
                                            double val = _swipeController.isAnimating ? _swipeController.value : 0.0;
                                            double scale = 0.88 + 0.06 * val;
                                            double top = 28.0 - 14.0 * val;
                                            double angle = (-7.0 + 12.0 * val) * (math.pi / 180);
                                            double opacity = 0.3 + 0.3 * val;

                                            return Positioned(
                                              top: top,
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Transform.rotate(
                                                  angle: angle,
                                                  child: _buildStackedCardBackground(
                                                    cardWidth,
                                                    cardHeight,
                                                    _profiles[(_activeIndex + 2) % _profiles.length],
                                                    opacity,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // 2. Middle card (Card 2 in Stack)
                                        AnimatedBuilder(
                                          animation: _swipeController,
                                          builder: (context, child) {
                                            double val = _swipeController.isAnimating ? _swipeController.value : 0.0;
                                            double scale = 0.94 + 0.06 * val;
                                            double top = 14.0 - 14.0 * val;
                                            double angle = (5.0 - 5.0 * val) * (math.pi / 180);
                                            double opacity = 0.6 + 0.4 * val;

                                            return Positioned(
                                              top: top,
                                              child: Transform.scale(
                                                scale: scale,
                                                child: Transform.rotate(
                                                  angle: angle,
                                                  child: _buildStackedCardBackground(
                                                    cardWidth,
                                                    cardHeight,
                                                    _profiles[(_activeIndex + 1) % _profiles.length],
                                                    opacity,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // 3. Active front card with swipe animation
                                        AnimatedBuilder(
                                          animation: Listenable.merge([
                                            _swipeController,
                                            _enterController,
                                          ]),
                                          builder: (context, child) {
                                            double tx = 0.0;
                                            double ty = 0.0;
                                            double rotZ = 0.0;
                                            double rotY = 0.0;
                                            double scale = 1.0;
                                            double opacity = 1.0;

                                            if (_swipeController.isAnimating) {
                                              // Exit animation
                                              double val = _swipeController.value;
                                              tx = _swipeDir * 380.0 * val;
                                              ty = -40.0 * val;
                                              rotZ = _swipeDir * 25.0 * (math.pi / 180) * val;
                                              rotY = _swipeDir * 15.0 * (math.pi / 180) * val;
                                              scale = 1.0 - (0.1 * val);
                                              opacity = (1.0 - val).clamp(0.0, 1.0);
                                            } else if (_enterController.isAnimating) {
                                              // Enter animation
                                              double val = _enterController.value;
                                              ty = 40.0 * (1.0 - val);
                                              scale = 0.9 + (0.1 * val);
                                              opacity = val.clamp(0.0, 1.0);
                                            }

                                            return Positioned(
                                              top: ty,
                                              left: tx,
                                              child: Transform(
                                                transform: Matrix4.identity()
                                                  ..setEntry(3, 2, 0.001) // perspective
                                                  ..rotateY(rotY)
                                                  ..rotateZ(rotZ)
                                                  ..scale(scale),
                                                alignment: Alignment.center,
                                                child: Opacity(
                                                  opacity: opacity,
                                                  child: _buildActiveCard(
                                                    cardWidth,
                                                    cardHeight,
                                                    _profiles[_activeIndex],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // Large heart popup on LIKE
                                        Center(
                                          child: AnimatedBuilder(
                                            animation: _heartPopupController,
                                            builder: (context, child) {
                                              if (!_heartPopupController.isAnimating) {
                                                return const SizedBox.shrink();
                                              }
                                              double val = _heartPopupController.value;
                                              // scale timeline: [0 -> 1.6 -> 1.3]
                                              double heartScale = 0.0;
                                              double heartOpacity = 0.0;
                                              double heartRotate = 0.0;

                                              if (val < 0.5) {
                                                double localT = val / 0.5;
                                                heartScale = localT * 1.6;
                                                heartOpacity = localT;
                                                heartRotate = localT * -0.17; // -10 degrees
                                              } else {
                                                double localT = (val - 0.5) / 0.5;
                                                heartScale = 1.6 - (localT * 0.3);
                                                heartOpacity = 1.0 - localT;
                                                heartRotate = -0.17 + (localT * 0.34); // from -10 to +10 degrees
                                              }

                                              return Transform.rotate(
                                                angle: heartRotate,
                                                child: Transform.scale(
                                                  scale: heartScale,
                                                  child: Opacity(
                                                    opacity: heartOpacity.clamp(0.0, 1.0),
                                                    child: const Icon(
                                                      Icons.favorite_rounded,
                                                      color: Color(0xFFEC4899),
                                                      size: 100,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black26,
                                                          blurRadius: 20,
                                                          offset: Offset(0, 8),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom CTAs
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                child: Column(
                                  children: [
                                    // Romance Gradient Button: Create Account
                                    _buildCTAButton(
                                      text: 'Create account',
                                      isPrimary: true,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    // Outline Button: Sign In
                                    _buildCTAButton(
                                      text: 'Sign in',
                                      isPrimary: false,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    // Terms & Privacy
                                    const Text(
                                      'By continuing you agree to our Terms and Privacy Policy.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Credits Link
                                    GestureDetector(
                                      onTap: () => _launchUrl('https://lazyrabbit.in'),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, child) {
                                            double opacity = 0.7 + 0.3 * math.sin(_pulseController.value * 2 * math.pi).abs();
                                            return Opacity(
                                              opacity: opacity,
                                              child: RichText(
                                                text: const TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                  children: [
                                                    TextSpan(text: 'made with '),
                                                    WidgetSpan(
                                                      alignment: PlaceholderAlignment.middle,
                                                      child: Icon(
                                                        Icons.favorite_rounded,
                                                        color: Color(0xFFEC4899),
                                                        size: 13,
                                                      ),
                                                    ),
                                                    TextSpan(text: ' by '),
                                                    TextSpan(
                                                      text: 'lazyrabbit.in',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFFEC4899),
                                                        decoration: TextDecoration.underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Blur Blob Builder ──────────────────────────────────────────────
  Widget _buildBlurBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.85],
        ),
      ),
    );
  }

  // ── Header Component ───────────────────────────────────────────────
  Widget _buildLogoHeader(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Image with bounce
        AnimatedBuilder(
          animation: _logoBounceController,
          builder: (context, child) {
            return Transform.scale(
              scale: _logoBounceScale.value,
              child: Transform.rotate(
                angle: _logoBounceRotate.value,
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFEC4899),
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        // MatchInMinutes Title
        const Text(
          'MatchInMinutes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9D174D), // pink-800 from splash screen
            letterSpacing: -0.5,
            height: 1.0,
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
            color: const Color(0xFFEC4899).withOpacity(0.75), // color from splash screen
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ── Stacked Card Background Builder ────────────────────────────────
  Widget _buildStackedCardBackground(
      double width, double height, Map<String, String> profile, double opacity) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEC4899).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Image.asset(
                profile['img']!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.grey,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54.withOpacity((opacity * 0.55).clamp(0.0, 1.0)),
                      Colors.black87.withOpacity((opacity * 0.9).clamp(0.0, 1.0)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active Card Builder ────────────────────────────────────────────
  Widget _buildActiveCard(double width, double height, Map<String, String> profile) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.20),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEC4899).withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Profile Image
            Image.asset(
              profile['img']!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.grey,
                  size: 64,
                ),
              ),
            ),

            // Black bottom overlay gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 180,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
            ),

            // Profile info text (Name, Age, City, Online dot)
            Positioned(
              left: 16,
              right: 16,
              bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${profile['name']}, ${profile['age']}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                      ),
                      // Online dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF34D399),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF34D399),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile['city']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Interactive Buttons Overlay (Attached to card bottom)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // X Button (NOPE)
                  _buildIconButton(
                    icon: Icons.close_rounded,
                    color: const Color(0xFFF43F5E),
                    borderColor: const Color(0xFFFECDD3),
                    onTap: () => _triggerSwipe(-1),
                    size: 46,
                  ),
                  const SizedBox(width: 14),
                  // Heart Button (LIKE)
                  _buildHeartButton(
                    onTap: () => _triggerSwipe(1),
                  ),
                  const SizedBox(width: 14),
                  // Star Button (SUPERLIKE)
                  _buildIconButton(
                    icon: Icons.star_rounded,
                    color: const Color(0xFFF59E0B),
                    borderColor: const Color(0xFFFEF3C7),
                    onTap: () => _triggerSwipe(1),
                    size: 46,
                  ),
                ],
              ),
            ),

            // LIKE / NOPE Text badges overlay
            if (_swipeController.isAnimating)
              Positioned(
                top: 24,
                left: _swipeDir == 1 ? 24 : null,
                right: _swipeDir == -1 ? 24 : null,
                child: Transform.rotate(
                  angle: _swipeDir == 1 ? -15 * (math.pi / 180) : 15 * (math.pi / 180),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _swipeDir == 1
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFEF4444).withOpacity(0.15),
                      border: Border.all(
                        color: _swipeDir == 1 ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _swipeDir == 1 ? 'LIKE' : 'NOPE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _swipeDir == 1 ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Small X/Star Card Buttons ──────────────────────────────────────
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required Color borderColor,
    required VoidCallback onTap,
    double size = 48,
  }) {
    return _InteractiveButton(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ── Romance Gradient Heart Card Button ──────────────────────────────
  Widget _buildHeartButton({required VoidCallback onTap}) {
    return _InteractiveButton(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withOpacity(0.40),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  // ── Bottom CTA Buttons Builder ─────────────────────────────────────
  Widget _buildCTAButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    if (isPrimary) {
      // Premium Romance Gradient Button with hover shimmer effect simulation
      return _InteractiveButton(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFB7185), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withOpacity(0.35),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      );
    } else {
      // Transparent Border Glass Button
      return _InteractiveButton(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEC4899).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Center(
            child: Text(
              'Sign in',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEC4899),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      );
    }
  }
}

// ── Interactive Scale Gesture Helper ─────────────────────────────────
class _InteractiveButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _InteractiveButton({required this.child, required this.onTap});

  @override
  State<_InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<_InteractiveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

// ── Floating Little Hearts System ───────────────────────────────────
class _FloatingLittleHearts extends StatelessWidget {
  final AnimationController pulseController;
  const _FloatingLittleHearts({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    // 10 floating heart positions matching React/CSS: left / top mappings
    final List<Offset> initialPositions = const [
      Offset(0.05, 0.08),
      Offset(0.16, 0.27),
      Offset(0.27, 0.46),
      Offset(0.38, 0.65),
      Offset(0.49, 0.84),
      Offset(0.60, 0.03),
      Offset(0.71, 0.22),
      Offset(0.82, 0.41),
      Offset(0.93, 0.60),
      Offset(0.08, 0.79),
    ];

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: List.generate(initialPositions.length, (i) {
            final pos = initialPositions[i];
            // Compute unique phase progress per heart using pulseController
            double progress = (pulseController.value + (i * 0.13)) % 1.0;

            // Offset Y oscillation: [0 -> -40 -> 0]
            double dy = math.sin(progress * 2 * math.pi) * -20.0;
            // Opacity timeline: [0.2 -> 0.7 -> 0.2]
            double opacity = 0.15 + (0.5 * math.sin(progress * math.pi).abs());
            // Rotation oscillation: [0 -> 20 -> -10 -> 0] degrees
            double rot = math.sin(progress * 2 * math.pi) * 0.3; // radians
            // Size mapping based on index
            double size = 12.0 + (i % 3) * 6.0;

            return Positioned(
              left: MediaQuery.of(context).size.width * pos.dx,
              top: MediaQuery.of(context).size.height * pos.dy + dy,
              child: Transform.rotate(
                angle: rot,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xFFEC4899).withOpacity(0.35),
                    size: size,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
