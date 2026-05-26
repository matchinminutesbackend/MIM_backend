import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'instant_match_chat_screen.dart';

enum _IMState { idle, searching, confirming, partnerSkipped }

class InstantMatchScreen extends StatefulWidget {
  const InstantMatchScreen({super.key});

  @override
  State<InstantMatchScreen> createState() => _InstantMatchScreenState();
}

class _InstantMatchScreenState extends State<InstantMatchScreen>
    with SingleTickerProviderStateMixin {
  _IMState _state = _IMState.idle;

  // Quota info
  bool _enabled    = true;
  bool _unlimited  = false;
  int? _remaining;
  int? _limit;
  bool _infoLoading = true;

  // Confirming state
  Map<String, dynamic>? _partner;
  String? _matchId;
  DateTime? _expiresAt;
  int _countdown = 5;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  // Pending "Add Friend" invites received while idle
  List<Map<String, dynamic>> _pendingInvites = [];
  bool _inviteActioning = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadInfo();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final data = await ApiService.instantMatchInfo();
      if (!mounted) return;
      setState(() {
        _enabled   = data['enabled'] != false;
        _unlimited = data['unlimited'] == true;
        _remaining = data['remaining'] as int?;
        _limit     = data['limit'] as int?;
        _infoLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _infoLoading = false);
    }
    _loadPendingInvites();
  }

  Future<void> _loadPendingInvites() async {
    try {
      final list = await ApiService.getPendingInstantInvites();
      if (!mounted) return;
      setState(() => _pendingInvites = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  Future<void> _acceptInvite(String matchId) async {
    setState(() => _inviteActioning = true);
    try {
      await ApiService.instantMatchChatAccept(matchId);
      await _loadPendingInvites();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _inviteActioning = false);
    }
  }

  Future<void> _declineInvite(String matchId) async {
    setState(() => _inviteActioning = true);
    try {
      await ApiService.instantMatchChatDecline(matchId);
      await _loadPendingInvites();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _inviteActioning = false);
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<void> _startSearch() async {
    setState(() => _state = _IMState.searching);
    try {
      final res = await ApiService.instantMatchJoin();
      if (!mounted) return;
      if (res['status'] == 'confirming') {
        _enterConfirming(res);
      } else {
        // waiting — start polling
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _state = _IMState.idle);
      _showError(e.message);
    }
  }

  Future<void> _poll() async {
    try {
      final res = await ApiService.instantMatchStatus();
      if (!mounted) return;
      if (res['status'] == 'confirming') {
        _pollTimer?.cancel();
        _enterConfirming(res);
      } else if (res['status'] == 'partner_skipped' || res['status'] == 'not_in_queue') {
        _pollTimer?.cancel();
        if (mounted) setState(() => _state = _IMState.partnerSkipped);
      }
    } catch (_) {}
  }

  void _enterConfirming(Map<String, dynamic> res) {
    _matchId = res['match_id'] as String?;
    _partner = res['partner'] as Map<String, dynamic>?;
    final expiresStr = res['expires_at'] as String?;
    _expiresAt = expiresStr != null ? DateTime.tryParse(expiresStr)?.toLocal() : null;
    _countdown = _expiresAt != null
        ? _expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 6)
        : 5;
    setState(() => _state = _IMState.confirming);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final secs = _expiresAt != null
          ? _expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 6)
          : _countdown - 1;
      setState(() => _countdown = secs);
      if (secs <= 0) {
        t.cancel();
        _confirm(); // auto-confirm when timer fires
      }
    });
  }

  Future<void> _cancel() async {
    _pollTimer?.cancel();
    try { await ApiService.instantMatchLeave(); } catch (_) {}
    if (mounted) setState(() => _state = _IMState.idle);
  }

  Future<void> _skip() async {
    _countdownTimer?.cancel();
    try { await ApiService.instantMatchSkip(); } catch (_) {}
    if (mounted) setState(() { _state = _IMState.searching; _partner = null; });
    // Re-join queue
    _startSearch();
  }

  Future<void> _confirm() async {
    _countdownTimer?.cancel();
    try {
      final res = await ApiService.instantMatchConfirm();
      if (!mounted) return;
      final mid = (res['match_id'] ?? _matchId) as String?;
      final partner = (res['partner'] ?? _partner) as Map<String, dynamic>?;
      if (mid != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstantMatchChatScreen(
              matchId: mid,
              partner: partner ?? {},
            ),
          ),
        );
        if (!mounted) return;
        // After chat ends, refresh quota and return to idle
        setState(() { _state = _IMState.idle; _partner = null; });
        _loadInfo();
      }
    } catch (_) {
      if (mounted) setState(() => _state = _IMState.idle);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          // Glow bg
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.1,
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.25),
                    const Color(0xFF0D0D1A),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () async {
            if (_state == _IMState.searching) await _cancel();
            if (mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
        ),
        const Expanded(
          child: Text('Instant Match',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
        const Icon(Icons.bolt_rounded, color: Color(0xFF8B5CF6), size: 24),
      ],
    ),
  );

  Widget _buildBody() {
    if (_infoLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }
    if (!_enabled) return _buildDisabled();

    return switch (_state) {
      _IMState.idle          => _buildIdle(),
      _IMState.searching     => _buildSearching(),
      _IMState.confirming    => _buildConfirming(),
      _IMState.partnerSkipped => _buildPartnerSkipped(),
    };
  }

  // Idle ─────────────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // ── Pending "Add Friend" invites ──────────────────────────────
          if (_pendingInvites.isNotEmpty) ...[
            ..._pendingInvites.map((inv) {
              final name   = inv['partner_name'] as String? ?? 'Someone';
              final photo  = inv['partner_photo'] as String?;
              final mid    = inv['match_id'] as String? ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0A2E), Color(0xFF0D1A2E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                      backgroundImage: photo != null ? NetworkImage(photo) : null,
                      child: photo == null ? Text(name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name wants to add you as a friend',
                              style: const TextStyle(color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          const Text('From your Instant Match chat',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _inviteActioning ? null : () => _declineInvite(mid),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white54, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _inviteActioning ? null : () => _acceptInvite(mid),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Accept', style: TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // ── Icon ─────────────────────────────────────────────────────
          Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 24, spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 28),

            const Text('Instant Match',
                style: TextStyle(color: Colors.white, fontSize: 26,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            const Text(
              'Get matched with someone compatible\nright now for a quick chat!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),

            // Quota info
            if (!_unlimited && _remaining != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _remaining! > 0 ? Icons.bolt_rounded : Icons.block_rounded,
                      color: _remaining! > 0 ? const Color(0xFF8B5CF6) : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _remaining! > 0
                          ? '$_remaining of $_limit free matches today'
                          : 'Daily limit reached · Upgrade to Pro',
                      style: TextStyle(
                        color: _remaining! > 0 ? Colors.white70 : Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_unlimited) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.all_inclusive, color: Color(0xFF8B5CF6), size: 18),
                    SizedBox(width: 8),
                    Text('Unlimited matches', style: TextStyle(
                        color: Color(0xFFA78BFA), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Find Match button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: (_remaining == null || _remaining! > 0 || _unlimited) ? _startSearch : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: (_remaining == null || _remaining! > 0 || _unlimited)
                        ? const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          )
                        : null,
                    color: (_remaining != null && _remaining! <= 0 && !_unlimited)
                        ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (_remaining == null || _remaining! > 0 || _unlimited)
                        ? [const BoxShadow(color: Color(0x558B5CF6),
                              blurRadius: 20, offset: Offset(0, 6))]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: (_remaining != null && _remaining! <= 0 && !_unlimited)
                              ? Colors.white38 : Colors.white,
                          size: 22),
                      const SizedBox(width: 8),
                      Text(
                        (_remaining != null && _remaining! <= 0 && !_unlimited)
                            ? 'Limit Reached' : 'Find Match',
                        style: TextStyle(
                          color: (_remaining != null && _remaining! <= 0 && !_unlimited)
                              ? Colors.white38 : Colors.white,
                          fontSize: 17, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),
          const Text(
            'Girls & Pro users · unlimited\nFree men · 2 matches per day',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Searching ────────────────────────────────────────────────────────────────

  Widget _buildSearching() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 120 + _pulseCtrl.value * 20,
              height: 120 + _pulseCtrl.value * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.4 - _pulseCtrl.value * 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 20, spreadRadius: 4,
                    )],
                  ),
                  child: const Icon(Icons.search_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text('Finding your match…',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Looking for someone compatible',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 40),
          TextButton.icon(
            onPressed: _cancel,
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            label: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // Confirming ───────────────────────────────────────────────────────────────

  Widget _buildConfirming() {
    final photo = _partner?['main_image_url'] as String?;
    final name  = _partner?['name'] as String? ?? 'Someone';
    final age   = _partner?['age'];
    final city  = _partner?['city'] as String?;
    final progress = _countdown / 5.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Match Found! 🎉',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Start chat before the timer runs out',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 32),

            // Countdown ring + photo
            SizedBox(
              width: 160, height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(160, 160),
                    painter: _CountdownRingPainter(progress: progress.clamp(0, 1)),
                  ),
                  ClipOval(
                    child: SizedBox(
                      width: 130, height: 130,
                      child: photo != null
                          ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _avatarFallback(name))
                          : _avatarFallback(name),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _countdown <= 2 ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6),
                        border: Border.all(color: const Color(0xFF0D0D1A), width: 3),
                      ),
                      child: Center(
                        child: Text('$_countdown',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(age != null ? '$name, $age' : name,
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w700)),
            if (city != null) ...[
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.location_on_rounded, color: Colors.white38, size: 14),
                const SizedBox(width: 3),
                Text(city, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ]),
            ],
            const SizedBox(height: 32),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _confirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(
                      color: Color(0x558B5CF6), blurRadius: 16, offset: Offset(0, 6),
                    )],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Start Chat', style: TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _skip,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Skip', style: TextStyle(color: Colors.white60, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
    color: const Color(0xFF2D1B33),
    child: Center(
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white54, fontSize: 48,
              fontWeight: FontWeight.bold)),
    ),
  );

  // Partner skipped ─────────────────────────────────────────────────────────

  Widget _buildPartnerSkipped() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.redo_rounded, color: Colors.white38, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Partner skipped',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('No worries — search again!',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _startSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('Search Again', style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // Disabled ─────────────────────────────────────────────────────────────────

  Widget _buildDisabled() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flash_off, color: Colors.white24, size: 64),
          const SizedBox(height: 20),
          const Text('Instant Match Unavailable',
              style: TextStyle(color: Colors.white60, fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('This feature has been temporarily disabled by the admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 13, height: 1.5)),
        ],
      ),
    ),
  );
}

// ─── Countdown ring painter ──────────────────────────────────────────────────

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  _CountdownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = cx - 6;

    // Track
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);

    // Arc
    if (progress > 0) {
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * progress,
        colors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      );
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.progress != progress;
}
