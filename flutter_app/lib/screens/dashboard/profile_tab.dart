import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/partner_preferences_screen.dart';
import '../gifts/gifts_inbox_screen.dart';
import '../profile/skipped_profiles_screen.dart';
import '../subscription/subscription_screen.dart';
import '../legal/terms_screen.dart';
import '../legal/privacy_screen.dart';
import '../help/help_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    // Refresh profile data on first load — picks up any admin decisions
    // that happened since the last app launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          final profile = auth.profile;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)));
          }
          return RefreshIndicator(
            color: const Color(0xFFEC4899),
            onRefresh: () => auth.refreshProfile(),
            child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.scaffoldBg(context),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                titleSpacing: 20,
                title: Text('My profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context))),
                actions: [
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: AppTheme.textSecondary(context), size: 22),
                    onPressed: () => _showSettings(context, auth),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Profile summary card ──────────────────────────
                      _ProfileSummaryCard(profile: profile, auth: auth),
                      const SizedBox(height: 14),

                      // ── Verification banner (handles own bottom margin) ─
                      _VerificationBanner(profile: profile, auth: auth),
                      // ── Premium / Earn-more banner (gender-aware) ─────
                      if ((profile.gender?.toLowerCase() ?? '') == 'female')
                        const _EarnMoreBanner()
                      else
                        _PremiumBanner(plan: profile.subscriptionPlan),
                      const SizedBox(height: 14),

                      // ── Menu items ────────────────────────────────────
                      _MenuCard(items: [
                        _MenuItem(
                          icon: Icons.tune_outlined,
                          label: 'Partner preferences',
                          subtitle: 'Find your kind of match.',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PartnerPreferencesScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.shield_outlined,
                          label: 'Need help?',
                          subtitle: 'We will help you sort it out.',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const HelpScreen())),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // ── Links card ────────────────────────────────────
                      _MenuCard(items: [
                        _MenuItem(
                          label: 'Terms and conditions',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const TermsScreen())),
                          showIcon: false,
                        ),
                        _MenuItem(
                          label: 'Privacy policy',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                          showIcon: false,
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // App version
                      Center(
                        child: Text('App Version 1.0.0',
                            style: TextStyle(fontSize: 12, color: AppTheme.textFaint(context))),
                      ),
                      const SizedBox(height: 8),

                      // Logout
                      Center(
                        child: GestureDetector(
                          onTap: () => _logout(context, auth),
                          child: const Text('Log out',
                              style: TextStyle(fontSize: 13, color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),   // CustomScrollView
        );     // RefreshIndicator
        },
      ),
    );
  }

  void _showSettings(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 20),
            SwitchListTile(
              secondary: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: AppTheme.textSecondary(context),
              ),
              title: Text(
                'Dark Mode',
                style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.w500),
              ),
              value: Theme.of(context).brightness == Brightness.dark,
              activeColor: AppTheme.primaryPink,
              onChanged: (_) {
                context.read<ThemeProvider>().toggleTheme();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                _logout(context, auth);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out', style: TextStyle(color: AppTheme.textPrimary(context))),
        content: Text('Are you sure you want to log out?', style: TextStyle(color: AppTheme.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await auth.logout();
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }
}

// ── Profile summary card ──────────────────────────────────────────────────────

class _ProfileSummaryCard extends StatelessWidget {
  final ProfileModel profile;
  final AuthProvider auth;
  const _ProfileSummaryCard({required this.profile, required this.auth});

  int _completionPct() => 100;

  @override
  Widget build(BuildContext context) {
    final pct = _completionPct();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Avatar with completion ring
          _RingAvatar(photoUrl: profile.mainPhotoUrl, name: profile.name ?? '', pct: pct),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.age != null
                      ? '${profile.name ?? 'You'}, ${profile.age}'
                      : profile.name ?? 'You',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEC4899)),
                    ),
                    child: Text(
                        pct >= 100 ? 'Edit profile' : 'Complete your profile',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFEC4899),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final int pct;
  const _RingAvatar({this.photoUrl, required this.name, required this.pct});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring
          CustomPaint(
            size: const Size(86, 86),
            painter: _RingPainter(progress: pct / 100, ringBgColor: AppTheme.border(context)),
          ),
          // Avatar
          ClipOval(
            child: SizedBox(
              width: 68, height: 68,
              child: photoUrl != null
                  ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppTheme.activeBg(context),
                      child: Center(
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                color: Color(0xFFEC4899))),
                      ),
                    ),
            ),
          ),
          // Percentage badge
          Positioned(
            bottom: 0, left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$pct%',
                  style: const TextStyle(fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringBgColor;
  const _RingPainter({required this.progress, required this.ringBgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final strokeWidth = 4.0;

    // Background ring
    canvas.drawCircle(center, radius,
        Paint()
          ..color = ringBgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.ringBgColor != ringBgColor;
}

// ── Premium banner ─────────────────────────────────────────────────────────────

class _PremiumBanner extends StatelessWidget {
  final String? plan;
  const _PremiumBanner({this.plan});

  @override
  Widget build(BuildContext context) {
    final isPro = plan != null &&
        (plan!.startsWith('pro') || plan!.startsWith('plus'));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0764), Color(0xFF6B21A8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF6B21A8).withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title — RichText avoids inner-Row overflow
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'MatchInMinutes ',
                        style: TextStyle(color: Colors.white70, fontSize: 14,
                            fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: 'Premium ',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '✦',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                const Text('Get noticed sooner and go on 3X as many dates',
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isPro
                ? null
                : () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: Text(isPro ? 'Active ✓' : 'Upgrade',
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Earn-more banner (female users) ───────────────────────────────────────────

class _EarnMoreBanner extends StatelessWidget {
  const _EarnMoreBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBE185D), Color(0xFFEC4899), Color(0xFFF97316)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gift icon — fixed size, never shrinks
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🎁', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          // Text block — takes all remaining space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // RichText prevents inner-Row overflow
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Earn more ',
                        style: TextStyle(color: Colors.white70, fontSize: 13,
                            fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: 'Gifts & Credits ',
                        style: TextStyle(color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '✨',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Get more likes — admirers send you gifts & credits',
                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CTA button — fixed width so it never wraps
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const GiftsInboxScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white38),
              ),
              child: const Text('View gifts',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verification banner ────────────────────────────────────────────────────────

class _VerificationBanner extends StatefulWidget {
  final ProfileModel profile;
  final AuthProvider auth;
  const _VerificationBanner({required this.profile, required this.auth});
  @override
  State<_VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<_VerificationBanner> {
  bool _uploading = false;
  bool _refreshing = false;

  Future<void> _checkStatus() async {
    setState(() => _refreshing = true);
    try {
      await widget.auth.refreshProfile();
      // AuthProvider notifies listeners → Consumer rebuilds → banner updates
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFEC4899)),
            title: Text('Take a selfie', style: TextStyle(color: AppTheme.textPrimary(context))),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFEC4899)),
            title: Text('Choose from gallery', style: TextStyle(color: AppTheme.textPrimary(context))),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    final p = await ImagePicker().pickImage(source: picked, imageQuality: 85, maxWidth: 1080);
    if (p == null) return;
    setState(() => _uploading = true);
    try {
      await ApiService.uploadVerificationSelfie(File(p.path));
      await widget.auth.refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selfie submitted — we\'ll review within 24 hours'),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.profile.verificationStatus?.toLowerCase() ?? 'none';
    final isDark = AppTheme.isDark(context);
    if (status == 'approved') return const SizedBox.shrink();

    switch (status) {
      case 'none':
        return _card(
          color: isDark ? const Color(0xFF2E1122) : const Color(0xFFFDF2F8),
          border: isDark ? const Color(0xFF5E193C) : const Color(0xFFFBCFE8),
          icon: Icons.face_retouching_natural_rounded,
          iconColor: const Color(0xFFEC4899),
          title: 'Verify your face to send likes',
          subtitle: 'Upload a selfie so our team can verify you. Once approved you can send likes to people.',
          action: _uploading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Color(0xFFEC4899)))
              : GestureDetector(
                  onTap: _pickAndUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Verify now',
                        style: TextStyle(fontSize: 12, color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
        );

      case 'pending':
        return _card(
          color: isDark ? const Color(0xFF241C10) : const Color(0xFFFFFBEB),
          border: isDark ? const Color(0xFF5C3E14) : const Color(0xFFFDE68A),
          icon: Icons.hourglass_top_outlined,
          iconColor: const Color(0xFFD97706),
          title: 'Selfie under review ⏳',
          subtitle: 'Our team is reviewing your selfie. You can browse profiles freely — likes unlock once approved.',
          action: _refreshing
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Color(0xFFD97706)))
              : GestureDetector(
                  onTap: _checkStatus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: const Text('Check status',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
        );

      case 'rejected':
        return _card(
          color: isDark ? const Color(0xFF2C1414) : const Color(0xFFFEF2F2),
          border: isDark ? const Color(0xFF5E1B1B) : const Color(0xFFFECACA),
          icon: Icons.cancel_outlined,
          iconColor: const Color(0xFFDC2626),
          title: 'Verification rejected',
          subtitle: widget.profile.verificationNote?.isNotEmpty == true
              ? '${widget.profile.verificationNote!} — please re-upload a clear selfie.'
              : 'Your selfie was not approved. Upload a new clear selfie to start sending likes.',
          action: _uploading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: Color(0xFFDC2626)))
              : GestureDetector(
                  onTap: _pickAndUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Re-submit',
                        style: TextStyle(fontSize: 12, color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _card({
    required Color color,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? action,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: iconColor)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context), height: 1.4)),
              if (action != null) ...[const SizedBox(height: 10), action],
            ]),
          ),
        ]),
      );
}

// ── Menu card ──────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(
      children: items.asMap().entries.map((e) {
        final isLast = e.key == items.length - 1;
        return Column(
          children: [
            e.value,
            if (!isLast)
              Divider(height: 1, indent: 60, endIndent: 16, color: AppTheme.border(context)),
          ],
        );
      }).toList(),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showIcon;

  const _MenuItem({
    this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (showIcon && icon != null) ...[
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.activeBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.textSecondary(context)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary(context))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 12, color: AppTheme.textFaint(context))),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textFaint(context), size: 20),
          ],
        ),
      ),
    );
  }
}
