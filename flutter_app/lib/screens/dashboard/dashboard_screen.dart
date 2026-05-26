import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../services/api_service.dart';
import '../../services/call_service.dart';
import '../../widgets/call_overlay.dart';
import '../../widgets/match_popup.dart';
import '../credits/credits_screen.dart';
import 'discover_tab.dart';
import 'matches_tab.dart';
import 'messages_tab.dart';
import 'profile_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Tab order: Matches(0), Credits(1), Discover(2), Messages(3), Profile(4)
  int _currentIndex = 2; // Start on Discover

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final msgs = context.read<MessagesProvider>();
    final call = context.read<CallService>();

    await call.init();
    _checkAd();

    if (auth.user != null) {
      msgs.connectSocket(auth.user!.id);
      msgs.socket.on('call_invite',  (d) => call.onIncomingCall(d));
      msgs.socket.on('call_accept',  (d) => call.onCallAccepted(d));
      msgs.socket.on('call_decline', (d) => call.onCallDeclined(d));
      msgs.socket.on('call_hangup',  (d) => call.onCallHangup(d));
      msgs.socket.on('call_offer',   (d) => call.onCallOffer(d));
      msgs.socket.on('call_answer',  (d) => call.onCallAnswer(d));
      msgs.socket.on('call_ice',     (d) => call.onIceCandidate(d));
      msgs.socket.on('call_error',   (d) => call.onCallError(d));

      // Show the universal match popup on any screen when a match is created.
      msgs.socket.on('match_created', (data) {
        if (!mounted) return;
        final partnerRaw = data['partner'];
        if (partnerRaw is! Map) return;
        final partner = Map<String, dynamic>.from(partnerRaw as Map);
        final myAuth = context.read<AuthProvider>();
        showDialog(
          context: context,
          barrierColor: Colors.black87,
          builder: (_) => MatchPopup(
            myName: myAuth.profile?.name,
            myPhoto: myAuth.profile?.mainPhotoUrl,
            partnerName: partner['name'] as String? ?? 'Someone',
            partnerPhoto: partner['main_image_url'] as String?,
            matchId: data['match_id'] as String?,
            partnerId: partner['id'] as String?,
          ),
        );
      });

      await msgs.loadMatches();
      await msgs.loadConversations();
    }
  }

  Future<void> _checkAd() async {
    final ad = await ApiService.getActiveAd();
    if (!mounted) return;
    final imageUrl = ad?['image_url'] as String?;
    final linkUrl  = ad?['link_url']  as String?;
    if (imageUrl == null || imageUrl.isEmpty) return;
    // Show once per app session using a static flag
    if (_DashboardScreenState._adShownThisSession) return;
    _DashboardScreenState._adShownThisSession = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AdPopup(imageUrl: imageUrl, linkUrl: linkUrl),
    );
  }

  static bool _adShownThisSession = false;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<MessagesProvider>().totalUnread;

    final tabs = [
      const MatchesTab(),
      const CreditsScreen(),
      const DiscoverTab(),
      const MessagesTab(),
      const ProfileTab(),
    ];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
          bottomNavigationBar: _CustomNavBar(
            currentIndex: _currentIndex,
            unread: unread,
            onTap: (i) => setState(() => _currentIndex = i),
          ),
        ),
        const Positioned.fill(child: CallOverlay()),
      ],
    );
  }
}

// ─── Custom bottom nav with highlighted center Discover button ────────────────

class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final int unread;
  final ValueChanged<int> onTap;

  const _CustomNavBar({
    required this.currentIndex,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      // Fixed nav height + device safe area
      height: 58 + bottomInset,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Padding(
        // Only add bottom padding for the safe-area inset — no extra
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavItem(index: 0, currentIndex: currentIndex,
                icon: Icons.favorite_border_rounded, activeIcon: Icons.favorite_rounded,
                label: 'Matches', onTap: onTap),
            _NavItem(index: 1, currentIndex: currentIndex,
                icon: Icons.bolt_outlined, activeIcon: Icons.bolt,
                label: 'Credits', onTap: onTap),

            // ── Discover centre button ──────────────────────────────
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        gradient: currentIndex == 2
                            ? const LinearGradient(
                                colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : const LinearGradient(
                                colors: [Color(0xFFFDE7F3), Color(0xFFFCE7F3)]),
                        shape: BoxShape.circle,
                        boxShadow: currentIndex == 2
                            ? [BoxShadow(
                                color: const Color(0x72EC4899),
                                blurRadius: 12, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Icon(Icons.explore_rounded,
                          color: currentIndex == 2
                              ? Colors.white
                              : const Color(0xFFEC4899),
                          size: 24),
                    ),
                    const SizedBox(height: 2),
                    Text('Discover',
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: currentIndex == 2
                              ? const Color(0xFFEC4899)
                              : const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),

            _NavItem(index: 3, currentIndex: currentIndex,
                icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded,
                label: 'Messages', badge: unread, onTap: onTap),
            _NavItem(index: 4, currentIndex: currentIndex,
                icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,
                label: 'Profile', onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFDE7F3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    color: selected
                        ? const Color(0xFFEC4899)
                        : const Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: selected
                    ? const Color(0xFFEC4899)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ad popup ─────────────────────────────────────────────────────────────────

class _AdPopup extends StatelessWidget {
  final String imageUrl;
  final String? linkUrl;
  const _AdPopup({required this.imageUrl, this.linkUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Poster image — tappable
          GestureDetector(
            onTap: () async {
              Navigator.pop(context);
              if (linkUrl != null && linkUrl!.isNotEmpty) {
                final uri = Uri.tryParse(linkUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFFEC4899))),
                ),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          // X close button
          Positioned(
            top: -12, right: -12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
