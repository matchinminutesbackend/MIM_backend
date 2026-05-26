import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discover_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/compatibility_questions.dart';
import '../../utils/time_utils.dart';
import '../../widgets/compatibility_section.dart';
import '../subscription/subscription_screen.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String userId;
  /// When non-null the viewer is looking at an existing match — the action bar
  /// switches from Like/Pass to Remove/Block.
  final String? matchId;
  const ProfileDetailScreen({super.key, required this.userId, this.matchId});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  DiscoverProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _reinviteSent = false;
  bool _liking = false;
  bool _passing = false;
  bool _removing = false;
  bool _blocking = false;

  static const _freePassLimit  = 15;
  static const _freeHeartLimit = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getProfileById(widget.userId);
      setState(() => _profile = DiscoverProfile.fromJson(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFEC4899))),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
            surfaceTintColor: Colors.transparent),
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(child: Text(_error ?? 'Profile not found',
            style: const TextStyle(color: Color(0xFF6B7280)))),
      );
    }
    final p = _profile!;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Photo header ──
              SliverAppBar(
                expandedHeight: 400,
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
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                  ),
                ),
                actions: [
                  GestureDetector(
                    onTap: () => _showReportSheet(context, p.userId),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.flag_outlined, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Report', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      p.displayPhoto != null
                          ? CachedNetworkImage(imageUrl: p.displayPhoto!, fit: BoxFit.cover)
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold,
                                      color: Colors.white54),
                                ),
                              ),
                            ),
                      // Gradient
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Name overlay
                      Positioned(
                        left: 20, right: 20, bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  p.age != null ? '${p.name}, ${p.age}' : p.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 26,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (p.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: Color(0xFF60A5FA), size: 20),
                                ],
                              ],
                            ),
                            if (p.city != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(p.city!,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

              // ── Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick detail chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (p.education != null)
                            _InfoChip(Icons.school_outlined, p.education!),
                          if (p.religion != null)
                            _InfoChip(Icons.temple_hindu_outlined, p.religion!),
                          if (p.relationshipGoal != null)
                            _InfoChip(Icons.favorite_border,
                                formatRelationshipGoal(p.relationshipGoal!)),
                        ],
                      ),

                      // Bio
                      if (p.bio != null && p.bio!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Card(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHead('About'),
                            const SizedBox(height: 8),
                            Text(p.bio!,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.6)),
                          ],
                        )),
                      ],

                      // Hobbies
                      if (p.hobbies.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Card(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHead('Hobbies'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: p.hobbies.map((h) => _Pill(h, pink: false)).toList(),
                            ),
                          ],
                        )),
                      ],

                      // Vibes
                      if (p.vibes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Card(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHead('Vibe'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: p.vibes.map((v) => _Pill(v, pink: true)).toList(),
                            ),
                          ],
                        )),
                      ],

                      // More photos
                      if (p.photoUrls.length > 1) ...[
                        const SizedBox(height: 12),
                        _Card(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHead('Photos'),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: p.photoUrls.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: p.photoUrls[i],
                                    width: 110, height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )),
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

          // ── Bottom action bar ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20,
                  MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                    blurRadius: 12, offset: const Offset(0, -3))],
              ),
              child: widget.matchId != null
                  ? _buildMatchActionBar(p)
                  : _buildDiscoverActionBar(p),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action bars ────────────────────────────────────────────────────────────

  /// Shown when the user is NOT yet matched — Pass / Reinvite / Send Like.
  Widget _buildDiscoverActionBar(DiscoverProfile p) {
    return Row(
      children: [
        // Pass
        GestureDetector(
          onTap: _passing ? null : () => _handlePass(p),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECACA)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: _passing
                ? const Padding(padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Color(0xFFEF4444), strokeWidth: 2))
                : const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 28),
          ),
        ),
        const SizedBox(width: 10),
        // Reinvite
        GestureDetector(
          onTap: _reinviteSent ? null : () async {
            try {
              await ApiService.reinviteUser(p.userId);
              if (mounted) {
                setState(() => _reinviteSent = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reinvitation sent! 🔄'),
                      backgroundColor: Color(0xFFD97706)));
              }
            } catch (_) {}
          },
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _reinviteSent ? const Color(0xFFF3F4F6) : const Color(0xFFFFFBEB),
              shape: BoxShape.circle,
              border: Border.all(color: _reinviteSent ? const Color(0xFFE5E7EB) : const Color(0xFFFDE68A)),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(
              _reinviteSent ? Icons.check_rounded : Icons.refresh_rounded,
              color: _reinviteSent ? const Color(0xFF9CA3AF) : const Color(0xFFD97706),
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildLikeButton(p)),
      ],
    );
  }

  /// Shown when the user IS already matched — Remove as Friend / Block.
  Widget _buildMatchActionBar(DiscoverProfile p) {
    return Row(
      children: [
        // Remove as Friend
        Expanded(
          child: GestureDetector(
            onTap: _removing ? null : () => _handleRemove(p),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: _removing
                  ? const Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Color(0xFFEF4444), strokeWidth: 2)))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 18),
                      SizedBox(width: 6),
                      Text('Remove Friend', style: TextStyle(
                          color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Block
        GestureDetector(
          onTap: _blocking ? null : () => _handleBlock(p),
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: _blocking
                ? const Padding(padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(color: Color(0xFF374151), strokeWidth: 2))
                : const Icon(Icons.block_rounded, color: Color(0xFF374151), size: 22),
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isFemale() {
    final gender = context.read<AuthProvider>().profile?.gender?.toLowerCase();
    return gender == 'female';
  }

  bool _isPro() {
    final plan = context.read<AuthProvider>().profile?.subscriptionPlan;
    return plan == 'plus' || plan == 'pro';
  }

  /// Girls get unlimited access — no subscription required.
  bool _hasUnlimitedAccess() => _isFemale() || _isPro();

  Widget _buildLikeButton(DiscoverProfile p) {
    final unlimited = _hasUnlimitedAccess();
    return GestureDetector(
      onTap: _liking ? null : () => _handleLike(p),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(
              color: const Color(0xFFEC4899).withOpacity(0.4),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_liking)
              const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else ...[
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Send Like',
                style: TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (!unlimited) ...[
                const SizedBox(width: 8),
                FutureBuilder<int>(
                  future: StorageService.getTodayLikeCount(),
                  builder: (_, snap) {
                    final used = snap.data ?? 0;
                    final left = (_freeHeartLimit - used).clamp(0, _freeHeartLimit);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$left left',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleLike(DiscoverProfile p) async {
    // Check free quota first (skip for unlimited users)
    if (!_hasUnlimitedAccess()) {
      final used = await StorageService.getTodayLikeCount();
      if (used >= _freeHeartLimit) {
        _showLikeLimitDialog();
        return;
      }
    }
    setState(() => _liking = true);
    try {
      final res = await ApiService.likeUser(p.userId);
      if (!mounted) return;
      // Only count the like after a successful API call
      if (!_hasUnlimitedAccess()) await StorageService.incrementLikeCount();
      if (res['match'] == true) {
        _showMatchDialog(context, p.name, p.displayPhoto);
      } else {
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        final detail = e.message;
        if (detail.contains('verify_pending')) {
          _showVerifyPendingDialog();
        } else if (detail.contains('verify_rejected')) {
          _showVerifyRejectedDialog();
        } else {
          _showVerifyRequiredDialog();
        }
      } else if (e.statusCode == 402) {
        _showLikeLimitDialog();
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _handlePass(DiscoverProfile p) async {
    if (!_hasUnlimitedAccess()) {
      final count = await StorageService.getTodayPassCount();
      if (count >= _freePassLimit) {
        _showPassLimitDialog();
        return;
      }
      await StorageService.incrementPassCount();
    }
    setState(() => _passing = true);
    try { await ApiService.passUser(p.userId); } catch (_) {}
    if (mounted) {
      setState(() => _passing = false);
      Navigator.pop(context);
    }
  }

  Future<void> _handleRemove(DiscoverProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove as friend?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text('You and ${p.name} will be unmatched. Your chat history will be preserved.',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing = true);
    try {
      await ApiService.unmatch(p.userId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _handleBlock(DiscoverProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Block this person?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(
          '${p.name} won\'t be able to send you likes, gifts, or match requests.\n\nYou\'ll also be unmatched.',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Block', style: TextStyle(color: Color(0xFF374151),
                  fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _blocking = true);
    try {
      await ApiService.blockUser(p.userId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _blocking = false);
    }
  }

  void _showQuotaDialog({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: Color(0xFF111827))),
              const SizedBox(height: 8),
              Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen()));
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFEC4899).withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Center(
                    child: Text('Upgrade to Plus ✨',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Maybe later',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLikeLimitDialog() => _showQuotaDialog(
    icon: Icons.favorite_rounded,
    iconBg: const Color(0xFFFDF2F8),
    iconColor: const Color(0xFFEC4899),
    title: 'Daily like limit reached',
    body: 'You\'ve used your $_freeHeartLimit free likes for today.\nUpgrade to Plus for unlimited likes.',
  );

  void _showPassLimitDialog() => _showQuotaDialog(
    icon: Icons.block_rounded,
    iconBg: const Color(0xFFFEF2F2),
    iconColor: const Color(0xFFEF4444),
    title: 'Daily pass limit reached',
    body: 'You\'ve used your $_freePassLimit free passes for today.\nUpgrade to Plus for unlimited passes.',
  );

  // ── Verification dialogs (3 states) ──────────────────────────────────────

  void _showVerifyPendingDialog() => _showVerifyInfoDialog(
    icon: Icons.hourglass_top_rounded,
    iconBg: const Color(0xFFFFFBEB),
    iconColor: const Color(0xFFD97706),
    title: 'Verification in progress',
    body: 'Your selfie is currently under review by our team.\nOnce approved, you\'ll be able to send likes.',
  );

  void _showVerifyRejectedDialog() => _showVerifyInfoDialog(
    icon: Icons.cancel_outlined,
    iconBg: const Color(0xFFFEF2F2),
    iconColor: const Color(0xFFEF4444),
    title: 'Verification rejected',
    body: 'Your selfie was not approved. Please go to your Profile tab and upload a new selfie to start sending likes.',
  );

  void _showVerifyRequiredDialog() => _showVerifyInfoDialog(
    icon: Icons.face_retouching_natural_rounded,
    iconBg: const Color(0xFFFDF2F8),
    iconColor: const Color(0xFFEC4899),
    title: 'Verify your face first',
    body: 'Upload a selfie to verify your identity before sending likes.\nGo to your Profile tab and tap "Verify your identity".',
  );

  void _showVerifyInfoDialog({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: Color(0xFF111827))),
              const SizedBox(height: 8),
              Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFFEC4899).withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Center(
                    child: Text('Got it',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context, String reportedId) {
    String? selectedReason;
    final descController = TextEditingController();
    bool submitting = false;

    const reasons = [
      'Fake profile / impersonation',
      'Inappropriate photos',
      'Harassment or abuse',
      'Spam or scam',
      'Underage user',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Report Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 4),
              const Text('Help us keep the community safe', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: reasons.map((r) {
                  final active = selectedReason == r;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedReason = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFFDF2F8) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? const Color(0xFFEC4899) : const Color(0xFFE5E7EB),
                            width: active ? 1.5 : 1),
                      ),
                      child: Text(r, style: TextStyle(fontSize: 13,
                          color: active ? const Color(0xFFEC4899) : const Color(0xFF374151),
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC4899))),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: submitting || selectedReason == null ? null : () async {
                    setModalState(() => submitting = true);
                    try {
                      await ApiService.submitReport(
                        reportedId: reportedId,
                        reason: selectedReason!,
                        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Report submitted. Our team will review it.'),
                          backgroundColor: Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (e) {
                      setModalState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Failed to submit: $e'),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMatchDialog(BuildContext context, String name, String? photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                ).createShader(b),
                child: const Text("It's a Match! 🎉",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text('You and $name liked each other',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              const SizedBox(height: 20),
              if (photo != null)
                CircleAvatar(radius: 40,
                    backgroundImage: CachedNetworkImageProvider(photo)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Keep Exploring',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub widgets ──

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFEC4899)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: child,
      );
}

class _SectionHead extends StatelessWidget {
  final String text;
  const _SectionHead(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final bool pink;
  const _Pill(this.text, {required this.pink});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: pink ? const Color(0xFFFDF2F8) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pink ? const Color(0xFFFBCFE8) : const Color(0xFFE5E7EB)),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 13,
                color: pink ? const Color(0xFFEC4899) : const Color(0xFF374151))),
      );
}
