import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discover_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../instant_match/instant_match_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_detail_screen.dart';
import '../subscription/subscription_screen.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> with SingleTickerProviderStateMixin {
  // Drag state
  Offset _drag = Offset.zero;
  bool _dragging = false;
  static const _threshold = 100.0;
  static const _freePassLimit  = 15;
  static const _freeHeartLimit = 5;

  // Cached today's counts so we don't hit storage on every build
  int _passesUsedToday = 0;
  int _likesUsedToday  = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _refreshCounts();
      await _applyPartnerPrefs(); // loads discover with saved preferences
    });
  }

  /// Reads partner preferences from AuthProvider (fetching if needed) and
  /// applies them as discover filters. Falls back to an empty filter set
  /// (shows everyone) if no preferences are saved yet.
  Future<void> _applyPartnerPrefs() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.partnerPreferences == null) {
      await auth.fetchPartnerPreferences();
    }
    if (!mounted) return;
    final prefs = auth.partnerPreferences ?? {};
    context.read<DiscoverProvider>().applyFilters(_prefsToFilters(prefs));
  }

  /// Converts partner-preference keys → discover filter keys that the
  /// backend `/matches/discover` endpoint understands.
  Map<String, String> _prefsToFilters(Map<String, dynamic> prefs) {
    final m = <String, String>{};
    final minAge = prefs['min_age'];
    final maxAge = prefs['max_age'];
    if (minAge != null) m['min_age'] = '$minAge';
    if (maxAge != null) m['max_age'] = '$maxAge';
    final city    = prefs['preferred_city']                as String?;
    final country = prefs['preferred_country']             as String?;
    final goal    = prefs['preferred_relationship_goal']   as String?;
    final edu     = prefs['preferred_education']           as String?;
    if (city    != null && city.isNotEmpty)       m['city']               = city;
    if (country != null && country.isNotEmpty)    m['country']            = country;
    if (goal    != null)                          m['relationship_goal']  = goal;
    if (edu     != null && edu != 'Any')          m['education_level']    = edu;
    return m;
  }

  Future<void> _refreshCounts() async {
    final passes = await StorageService.getTodayPassCount();
    final likes  = await StorageService.getTodayLikeCount();
    if (mounted) setState(() { _passesUsedToday = passes; _likesUsedToday = likes; });
  }

  // ── Access helpers ────────────────────────────────────────────────────────
  // Girls get unlimited likes + passes with no subscription required.

  bool _isFemale() {
    final gender = context.read<AuthProvider>().profile?.gender?.toLowerCase();
    return gender == 'female';
  }

  bool _isPro() {
    final plan = context.read<AuthProvider>().profile?.subscriptionPlan;
    return plan == 'plus' || plan == 'pro';
  }

  /// True if the user has unlimited access — either female or a paid subscriber.
  bool _hasUnlimitedAccess() => _isFemale() || _isPro();

  void _goToSubscription() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }

  // ── Drag handlers ─────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails _) => setState(() => _dragging = true);

  // Keep legacy _refreshPassCount for _doPass
  Future<void> _refreshPassCount() async {
    final count = await StorageService.getTodayPassCount();
    if (mounted) setState(() => _passesUsedToday = count);
  }

  void _onPanUpdate(DragUpdateDetails d) =>
      setState(() => _drag += d.delta);

  void _onPanEnd(DragEndDetails _) {
    if (_drag.dx > _threshold) {
      _doLike();
    } else if (_drag.dx < -_threshold) {
      _doPass();
    } else {
      setState(() { _drag = Offset.zero; _dragging = false; });
    }
  }

  // ── Verification gate — checked before any action that requires it ──────────

  /// Returns true if the current user is verified and can take actions.
  /// If not verified, shows the appropriate card and returns false.
  bool _checkVerified() {
    final profile = context.read<AuthProvider>().profile;
    if (profile?.isVerified == true) return true;
    final status = profile?.verificationStatus ?? 'none';
    _showVerificationGateCard(status);
    return false;
  }

  void _showVerificationGateCard(String status) {
    final isPending  = status == 'pending';
    final isRejected = status == 'rejected';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Icon
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: isPending
                    ? const Color(0xFFFFFBEB)
                    : isRejected
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0F9FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPending
                      ? const Color(0xFFFDE68A)
                      : isRejected
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFBAE6FD),
                  width: 2,
                ),
              ),
              child: Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : isRejected
                        ? Icons.cancel_outlined
                        : Icons.face_retouching_natural_rounded,
                size: 36,
                color: isPending
                    ? const Color(0xFFD97706)
                    : isRejected
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPending
                  ? 'Profile Under Review'
                  : isRejected
                      ? 'Verification Rejected'
                      : 'Verify Your Identity',
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold,
                color: Color(0xFF111827), letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isPending
                  ? 'Your selfie is being reviewed by our team.\n\nUntil approved:\n  • You cannot like anyone\n  • Your profile is hidden from others\n\nWe\'ll notify you once it\'s done — usually within 24 hours.'
                  : isRejected
                      ? 'Your selfie was not approved. Please upload a new selfie from your Profile tab to get verified.\n\nUntil verified:\n  • You cannot like anyone\n  • Your profile stays hidden'
                      : 'Upload a selfie to verify your identity.\n\nUntil verified:\n  • You cannot like anyone\n  • Your profile stays hidden from others',
              style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 14, height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (!isPending)
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  // Switch to profile tab (index 3)
                  // Dispatch via root navigator if possible
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(0.35),
                        blurRadius: 14, offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('Go to Profile → Upload Selfie',
                      style: TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            if (!isPending) const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  isPending ? 'Got it, I\'ll wait' : 'Maybe later',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Like — 5 free/day for all users; unlimited for girls + paid ──────────

  Future<void> _doLike() async {
    // Proactive verification gate — no API call made if not verified
    setState(() { _drag = Offset.zero; _dragging = false; });
    if (!_checkVerified()) return;

    final unlimited = _hasUnlimitedAccess();
    if (!unlimited && _likesUsedToday >= _freeHeartLimit) {
      _showLikeLimitDialog();
      return;
    }

    final prov = context.read<DiscoverProvider>();
    if (prov.profiles.isEmpty) return;
    final profile = prov.profiles.first;
    setState(() => _drag = const Offset(600, 0));
    await Future.delayed(const Duration(milliseconds: 280));
    prov.removeTopCard();
    if (mounted) setState(() { _drag = Offset.zero; _dragging = false; });
    try {
      await ApiService.likeUser(profile.userId);
      if (!unlimited) {
        await StorageService.incrementLikeCount();
        final count = await StorageService.getTodayLikeCount();
        if (mounted) setState(() => _likesUsedToday = count);
      }
      // Match popup shown globally via WebSocket 'match_created' in DashboardScreen.
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        if (!mounted) return;
        final status = context.read<AuthProvider>().profile?.verificationStatus ?? 'none';
        _showVerificationGateCard(status);
      } else if (e.statusCode == 402) {
        if (mounted) _showLikeLimitDialog();
      }
    } catch (_) {}
  }

  // ── Pass — 15/day for free users ─────────────────────────────────────────

  Future<void> _doPass() async {
    if (!_hasUnlimitedAccess()) {
      if (_passesUsedToday >= _freePassLimit) {
        setState(() { _drag = Offset.zero; _dragging = false; });
        _showPassLimitDialog();
        return;
      }
      await StorageService.incrementPassCount();
      await _refreshPassCount();
    }

    final prov = context.read<DiscoverProvider>();
    if (prov.profiles.isEmpty) return;
    final profile = prov.profiles.first;
    setState(() => _drag = const Offset(-600, 0));
    await Future.delayed(const Duration(milliseconds: 280));
    prov.removeTopCard();
    if (mounted) setState(() { _drag = Offset.zero; _dragging = false; });
    try { await ApiService.passUser(profile.userId); } catch (_) {}
  }

  // ── Gift like (super like with gift picker + optional message) ──────────────

  Future<void> _doGiftLike() async {
    if (!_checkVerified()) return;

    final prov = context.read<DiscoverProvider>();
    if (prov.profiles.isEmpty) return;
    final profile = prov.profiles.first;

    final unlimited = _hasUnlimitedAccess();
    if (!unlimited && _likesUsedToday >= _freeHeartLimit) {
      _showLikeLimitDialog();
      return;
    }

    // Show gift picker sheet — returns {slug, message} or null if cancelled
    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftPickerSheet(recipientName: profile.name),
    );
    if (!mounted || result == null) return;

    setState(() => _drag = const Offset(600, 0));
    await Future.delayed(const Duration(milliseconds: 280));
    prov.removeTopCard();
    if (mounted) setState(() { _drag = Offset.zero; _dragging = false; });

    try {
      await ApiService.giftLikeUser(
        profile.userId,
        message: result['message'],
        giftSlug: result['slug'],
      );
      if (!unlimited) {
        await StorageService.incrementLikeCount();
        final count = await StorageService.getTodayLikeCount();
        if (mounted) setState(() => _likesUsedToday = count);
      }
      // Match popup is handled via WebSocket 'match_created' in DashboardScreen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gift sent to ${profile.name}! 🎁'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        final status = context.read<AuthProvider>().profile?.verificationStatus ?? 'none';
        _showVerificationGateCard(status);
      } else if (e.statusCode == 402) {
        _showLikeLimitDialog();
      }
    } catch (_) {}
  }

  // ── Credit / quota bottom sheets ──────────────────────────────────────────

  void _showLikeLimitDialog() => _showCreditBottomSheet(
    icon: Icons.favorite_rounded,
    iconColor: const Color(0xFFEC4899),
    title: 'Daily likes used up',
    subtitle: 'You\'ve used all $_freeHeartLimit free likes for today. Upgrade to get unlimited likes and never miss a connection.',
  );

  void _showPassLimitDialog() => _showCreditBottomSheet(
    icon: Icons.block_rounded,
    iconColor: const Color(0xFFEF4444),
    title: 'Daily passes used up',
    subtitle: 'You\'ve used all $_freePassLimit free passes for today. Upgrade to browse without limits.',
  );

  void _showCreditBottomSheet({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 28, right: 28, top: 12,
          bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            // Gradient icon badge
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [iconColor.withOpacity(0.15), iconColor.withOpacity(0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.25), width: 1.5),
              ),
              child: Icon(icon, color: iconColor, size: 34),
            ),
            const SizedBox(height: 20),
            Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 14, height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            // Feature list
            _UpgradeFeatureRow(icon: Icons.all_inclusive_rounded, label: 'Unlimited likes & passes every day'),
            _UpgradeFeatureRow(icon: Icons.visibility_rounded,    label: 'See who liked your profile'),
            _UpgradeFeatureRow(icon: Icons.star_rounded,          label: 'Priority in discover feed'),
            const SizedBox(height: 28),
            // Primary CTA
            GestureDetector(
              onTap: () { Navigator.pop(context); _goToSubscription(); },
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withOpacity(0.35),
                      blurRadius: 16, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('Upgrade Now ✨',
                    style: TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold, letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('Maybe later',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Verification dialogs (3 states) ──────────────────────────────────────

  /// Selfie uploaded and awaiting admin review.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: Consumer<DiscoverProvider>(
        builder: (_, prov, __) {
          if (prov.loading && prov.profiles.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFEC4899)));
          }
          if (prov.profiles.isEmpty) {
            return _Empty(
              onRefresh: () => prov.load(refresh: true),
              errorMessage: prov.error,
            );
          }
          return Column(
            children: [
              Expanded(child: _buildCardStack(prov)),
              _buildButtons(),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    title: const Text('Discover',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: Color(0xFF111827))),
    actions: [
      IconButton(
        tooltip: 'Instant Match',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InstantMatchScreen())),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
        ),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.notifications_outlined,
              size: 20, color: Color(0xFF374151)),
        ),
      ),
      const SizedBox(width: 8),
    ],
  );

  Widget _buildCardStack(DiscoverProvider prov) {
    final profiles = prov.profiles;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Back cards (static, slightly scaled down)
        if (profiles.length >= 3)
          _BackCard(profile: profiles[2], index: 2),
        if (profiles.length >= 2)
          _BackCard(profile: profiles[1], index: 1),
        // Top card (draggable)
        _TopCard(
          profile: profiles.first,
          drag: _drag,
          dragging: _dragging,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProfileDetailScreen(userId: profiles.first.userId))),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    final unlimited = _hasUnlimitedAccess();
    final likesLeft  = (_freeHeartLimit - _likesUsedToday).clamp(0, _freeHeartLimit);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── Reject ────────────────────────────────────────────
          _ActionButton(
            icon: Icons.close_rounded,
            label: 'Reject',
            color: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            size: 58,
            onTap: _doPass,
          ),

          // ── Gift Like ─────────────────────────────────────────
          _ActionButton(
            icon: Icons.card_giftcard_rounded,
            label: 'Gift',
            color: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
            size: 54,
            onTap: _doGiftLike,
          ),

          // ── Heart / Like ──────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _ActionButton(
                icon: Icons.favorite_rounded,
                label: 'Like',
                color: Colors.white,
                bgColor: (unlimited || likesLeft > 0)
                    ? const Color(0xFFEC4899)
                    : const Color(0xFFEC4899).withOpacity(0.4),
                size: 68,
                onTap: _doLike,
                shadow: true,
              ),
              if (!unlimited)
                Positioned(
                  top: -4, right: -4,
                  child: _CountBadge(
                    count: likesLeft,
                    color: likesLeft > 0
                        ? const Color(0xFFEC4899)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),

          // ── Send / Super Invite ───────────────────────────────
          _ActionButton(
            icon: Icons.send_rounded,
            label: 'Send',
            color: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
            size: 54,
            onTap: _doSendInvite,
          ),
        ],
      ),
    );
  }

  Future<void> _doSendInvite() async {
    if (!_checkVerified()) return;
    final prov = context.read<DiscoverProvider>();
    if (prov.profiles.isEmpty) return;
    final profile = prov.profiles.first;
    try {
      await ApiService.sendSuperInvite(profile.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invite sent to ${profile.name} ✨'),
        backgroundColor: const Color(0xFF8B5CF6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (_) {
      if (!mounted) return;
      _showCreditBottomSheet(
        icon: Icons.send_rounded,
        iconColor: const Color(0xFF8B5CF6),
        title: 'No Super Invites left',
        subtitle: 'Upgrade your plan to send unlimited invites and stand out.',
      );
    }
  }

}

// ─── Card widgets ─────────────────────────────────────────────────────────────

class _TopCard extends StatelessWidget {
  final DiscoverProfile profile;
  final Offset drag;
  final bool dragging;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onTap;

  const _TopCard({
    required this.profile,
    required this.drag,
    required this.dragging,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final angle = drag.dx / 350;
    final likeOpacity = (drag.dx / 120).clamp(0.0, 1.0);
    final passOpacity = (-drag.dx / 120).clamp(0.0, 1.0);
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: onTap,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: AnimatedContainer(
        duration: dragging ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(drag.dx, drag.dy * 0.3)
          ..rotateZ(angle * 0.08),
        transformAlignment: Alignment.bottomCenter,
        child: SizedBox(
          width: size.width - 32,
          height: size.height * 0.60,
          child: Stack(
            children: [
              // Card itself
              _ProfileCard(profile: profile, isTop: true),
              // LIKE stamp
              if (likeOpacity > 0)
                Positioned(
                  top: 40, left: 24,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: _Stamp(label: 'LIKE', color: const Color(0xFF22C55E)),
                  ),
                ),
              // NOPE stamp
              if (passOpacity > 0)
                Positioned(
                  top: 40, right: 24,
                  child: Opacity(
                    opacity: passOpacity,
                    child: _Stamp(label: 'NOPE', color: const Color(0xFFEF4444)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  final DiscoverProfile profile;
  final int index;
  const _BackCard({required this.profile, required this.index});

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 - index * 0.05;
    final yOffset = index * 10.0;
    final size = MediaQuery.of(context).size;
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..translate(0.0, yOffset)
        ..scale(scale),
      child: IgnorePointer(
        child: SizedBox(
          width: size.width - 32,
          height: size.height * 0.60,
          child: _ProfileCard(profile: profile, isTop: false),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DiscoverProfile profile;
  final bool isTop;
  const _ProfileCard({required this.profile, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final photo = profile.displayPhoto;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isTop
            ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6))]
            : [],
        color: Colors.grey.shade300,
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
                  placeholder: (_, __) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFDE7F3), Color(0xFFF3E8FF)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 80, color: Colors.white54),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _noPhoto(),
                )
              : _noPhoto(),

          // Bottom gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // "Liked you" badge
          if (isTop && profile.likedMe)
            Positioned(
              top: 14, right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Liked you',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),

          // Info overlay
          if (isTop)
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          profile.age != null ? '${profile.name}, ${profile.age}' : profile.name,
                          style: const TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.bold, shadows: [
                            Shadow(blurRadius: 8, color: Colors.black38),
                          ]),
                        ),
                      ),
                      if (profile.isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 6, bottom: 2),
                          child: Icon(Icons.verified, color: Color(0xFF60A5FA), size: 20),
                        ),
                    ],
                  ),
                  if (profile.city != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white60, size: 14),
                      const SizedBox(width: 3),
                      Text(profile.city!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ],
                  if (profile.hobbies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: profile.hobbies.take(3).map((h) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(h,
                            style: const TextStyle(color: Colors.white, fontSize: 12,
                                fontWeight: FontWeight.w500)),
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

  Widget _noPhoto() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFDE7F3), Color(0xFFF3E8FF)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white54)),
  );
}

class _Stamp extends StatelessWidget {
  final String label;
  final Color color;
  const _Stamp({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: TextStyle(
      color: color, fontSize: 24, fontWeight: FontWeight.w900,
      letterSpacing: 2,
    )),
  );
}

// ─── Action button with label ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final double size;
  final VoidCallback onTap;
  final bool shadow;
  const _ActionButton({
    required this.icon, required this.label,
    required this.color, required this.bgColor,
    required this.size, required this.onTap, this.shadow = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: bgColor, shape: BoxShape.circle,
            boxShadow: shadow
                ? [BoxShadow(color: bgColor.withOpacity(0.5), blurRadius: 18, offset: const Offset(0, 6))]
                : [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: color, size: size * 0.46),
        ),
        const SizedBox(height: 6),
        Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      ],
    ),
  );
}

// ─── Upgrade feature row ──────────────────────────────────────────────────────

class _UpgradeFeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _UpgradeFeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF22C55E), size: 18),
      ),
      const SizedBox(width: 12),
      Text(label,
        style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
    ]),
  );
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    constraints: const BoxConstraints(minWidth: 18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}


// ─── Gift Picker Bottom Sheet ─────────────────────────────────────────────────

class _GiftPickerSheet extends StatefulWidget {
  final String recipientName;
  const _GiftPickerSheet({required this.recipientName});
  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet> {
  List<dynamic> _catalog = [];
  bool _loading = true;
  Map<String, dynamic>? _selected;
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getGiftCatalog();
      if (mounted) setState(() { _catalog = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle + Header
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Gradient header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Send a Gift 🎁',
                        style: TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold)),
                      Text('${widget.recipientName} will see your gift highlighted',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Gift grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Choose a gift',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF374151))),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                ),
              )
            else if (_catalog.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text('No gifts available right now',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _catalog.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final g = _catalog[i] as Map<String, dynamic>;
                    final isSelected = _selected?['slug'] == g['slug'];
                    return GestureDetector(
                      onTap: () => setState(() => _selected = isSelected ? null : g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 80,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                                  blurRadius: 8, offset: const Offset(0, 3))]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(g['icon'] as String? ?? '🎁',
                              style: const TextStyle(fontSize: 30)),
                            const SizedBox(height: 4),
                            Text(g['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                            const SizedBox(height: 2),
                            Text('${g['cost']} 💰',
                              style: const TextStyle(fontSize: 10,
                                  color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            // Message field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal message (optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _msgCtrl,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Say something nice to ${widget.recipientName}…',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      counterStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, {
                      'slug': _selected?['slug'] as String?,
                      'message': _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                            blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_selected != null
                              ? (_selected!['icon'] as String? ?? '🎁')
                              : '🎁',
                            style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          const Text('Send Gift',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onRefresh;
  final String? errorMessage;
  const _Empty({required this.onRefresh, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final isError = errorMessage != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFDF2F8),
              shape: BoxShape.circle,
              border: Border.all(color: isError
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFFBCFE8)),
            ),
            child: Icon(
              isError ? Icons.wifi_off_rounded : Icons.search_off_rounded,
              size: 48,
              color: isError
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFEC4899),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isError ? 'Could not load profiles' : 'No more profiles',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            isError
                ? errorMessage!
                : 'Check back later or adjust your filters',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(isError ? 'Retry' : 'Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ]),
      ),
    );
  }
}


