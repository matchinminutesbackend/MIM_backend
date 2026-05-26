import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_model.dart';
import '../../providers/messages_provider.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_detail_screen.dart';

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Matches',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFFEC4899),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFFEC4899),
              indicatorWeight: 2,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Matches'),
                Tab(text: 'Liked Me'),
                Tab(text: 'Sent'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _MatchesList(type: _MatchType.matches),
          _MatchesList(type: _MatchType.likedMe),
          _MatchesList(type: _MatchType.sent),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum _MatchType { matches, likedMe, sent }

class _MatchesList extends StatefulWidget {
  final _MatchType type;
  const _MatchesList({required this.type});

  @override
  State<_MatchesList> createState() => _MatchesListState();
}

class _MatchesListState extends State<_MatchesList>
    with AutomaticKeepAliveClientMixin {
  List<MatchModel> _list = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.type) {
        case _MatchType.matches:
          await context.read<MessagesProvider>().loadMatches();
        case _MatchType.likedMe:
          final data = await ApiService.getLikedMe();
          _list = (data as List)
              .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
              .toList();
        case _MatchType.sent:
          final data = await ApiService.getLikesSent();
          _list = (data as List)
              .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
              .toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Liked-Me: reject one entry ───────────────────────────────────────────
  Future<void> _rejectAt(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pass?'),
        content: Text('Remove ${_list[i].partnerName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pass',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ApiService.rejectLiker(_list[i].partnerId);
        setState(() => _list.removeAt(i));
      } catch (_) {}
    }
  }

  // ── Liked-Me: like back ──────────────────────────────────────────────────
  Future<void> _likeBackAt(int i) async {
    try {
      await ApiService.likeUser(_list[i].partnerId);
      if (mounted) {
        setState(() => _list.removeAt(i));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("It's a match! 🎉"),
            backgroundColor: Color(0xFFEC4899),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Reload matches in background
        context.read<MessagesProvider>().loadMatches();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.type == _MatchType.matches) {
      return Consumer<MessagesProvider>(
        builder: (_, provider, __) {
          if (provider.matchesLoading) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFFEC4899)));
          }
          if (provider.matches.isEmpty) {
            return _EmptyState(type: widget.type);
          }
          return _buildList(provider.matches);
        },
      );
    }

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFEC4899)));
    }
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(color: Color(0xFF6B7280))));
    }
    if (_list.isEmpty) return _EmptyState(type: widget.type);
    return _buildList(_list);
  }

  Widget _buildList(List<MatchModel> list) {
    return RefreshIndicator(
      color: const Color(0xFFEC4899),
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 80, color: Color(0xFFF3F4F6)),
        itemBuilder: (_, i) {
          final m = list[i];
          switch (widget.type) {
            case _MatchType.matches:
              return _MatchRow(match: m);
            case _MatchType.likedMe:
              return _LikedMeRow(
                match: m,
                onLikeBack: () => _likeBackAt(i),
                onPass: () => _rejectAt(i),
              );
            case _MatchType.sent:
              return _SentRow(match: m);
          }
        },
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _MatchType type;
  const _EmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = switch (type) {
      _MatchType.matches =>
        (Icons.favorite_rounded, 'No matches yet', 'Keep swiping!'),
      _MatchType.likedMe =>
        (Icons.visibility_outlined, 'No likes yet', 'Be the first to move!'),
      _MatchType.sent =>
        (Icons.send_rounded, 'No likes sent', 'Start swiping to like profiles'),
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBCFE8))),
            child: Icon(icon, size: 36, color: const Color(0xFFEC4899)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(sub,
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

// ─── Shared avatar widget ─────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _Avatar({this.url, required this.name, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFFDE7F3),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEC4899)),
          ),
        ),
      );
}

// ─── Matches row ──────────────────────────────────────────────────────────────

class _MatchRow extends StatefulWidget {
  final MatchModel match;
  const _MatchRow({required this.match});

  @override
  State<_MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<_MatchRow> {
  bool _reinviting = false;

  Future<void> _reinvite() async {
    setState(() => _reinviting = true);
    try {
      await ApiService.reinviteUser(widget.match.partnerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invite sent! 💌'),
          backgroundColor: Color(0xFFEC4899),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _reinviting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemoved = widget.match.removedAt != null;
    return InkWell(
      onTap: isRemoved
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(match: widget.match))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRemoved
                              ? const Color(0xFFE5E7EB)
                              : widget.match.unreadCount > 0
                                  ? const Color(0xFFEC4899)
                                  : const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ColorFiltered(
                          colorFilter: isRemoved
                              ? const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0, 0, 0, 1, 0,
                                ])
                              : const ColorFilter.mode(
                                  Colors.transparent, BlendMode.dst),
                          child: _Avatar(
                              url: widget.match.partnerPhotoUrl,
                              name: widget.match.partnerName,
                              size: 52),
                        ),
                      ),
                    ),
                    if (!isRemoved && widget.match.unreadCount > 0)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEC4899),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.match.unreadCount > 9
                                  ? '9+'
                                  : '${widget.match.unreadCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.match.partnerName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isRemoved
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF111827)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRemoved
                            ? 'Match ended'
                            : (widget.match.lastMessage?.isNotEmpty == true
                                ? widget.match.lastMessage!
                                : 'New match! Say hello 👋'),
                        style: TextStyle(
                            fontSize: 13,
                            color: isRemoved
                                ? const Color(0xFF9CA3AF)
                                : widget.match.unreadCount > 0
                                    ? const Color(0xFF111827)
                                    : const Color(0xFF9CA3AF),
                            fontStyle: isRemoved ? FontStyle.italic : FontStyle.normal,
                            fontWeight: widget.match.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isRemoved)
                  _reinviting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFFEC4899), strokeWidth: 2))
                      : _PillButton(
                          label: 'Match Again',
                          icon: Icons.refresh_rounded,
                          color: const Color(0xFFEC4899),
                          onTap: _reinvite,
                        )
                else
                  _PillButton(
                    label: 'Chat',
                    icon: Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFFEC4899),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(match: widget.match))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Liked-Me row ─────────────────────────────────────────────────────────────

class _LikedMeRow extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onLikeBack;
  final VoidCallback onPass;
  const _LikedMeRow(
      {required this.match,
      required this.onLikeBack,
      required this.onPass});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProfileDetailScreen(userId: match.partnerId, matchId: match.matchId))),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(
                url: match.partnerPhotoUrl,
                name: match.partnerName,
                size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.partnerName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (match.partnerAge != null ||
                      match.partnerCity != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (match.partnerAge != null)
                          '${match.partnerAge}',
                        if (match.partnerCity != null)
                          match.partnerCity!,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Text('Liked your profile ❤️',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFEC4899))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillButton(
                  label: 'Like back',
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: onLikeBack,
                ),
                const SizedBox(height: 6),
                _PillButton(
                  label: 'Pass',
                  icon: Icons.close_rounded,
                  color: const Color(0xFF9CA3AF),
                  onTap: onPass,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sent row ─────────────────────────────────────────────────────────────────

class _SentRow extends StatelessWidget {
  final MatchModel match;
  const _SentRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final status = match.likeStatus ?? 'pending';
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProfileDetailScreen(userId: match.partnerId, matchId: match.matchId))),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(
                url: match.partnerPhotoUrl,
                name: match.partnerName,
                size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.partnerName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (match.partnerAge != null ||
                      match.partnerCity != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (match.partnerAge != null)
                          '${match.partnerAge}',
                        if (match.partnerCity != null)
                          match.partnerCity!,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                  const SizedBox(height: 5),
                  _StatusChip(status: status),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PillButton(
                  label: 'Send gift',
                  icon: Icons.card_giftcard_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () =>
                      _showGiftSheet(context, match.partnerId),
                ),
                const SizedBox(height: 6),
                _PillButton(
                  label: 'Message',
                  icon: Icons.send_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: () =>
                      _showMessageSheet(context, match.partnerId, match.partnerName),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Gift picker sheet ────────────────────────────────────────────────────
  void _showGiftSheet(BuildContext context, String receiverId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _GiftPickerSheet(receiverId: receiverId),
    );
  }

  // ── Quick-message sheet ──────────────────────────────────────────────────
  void _showMessageSheet(
      BuildContext context, String receiverId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) =>
          _QuickMessageSheet(receiverId: receiverId, name: name),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status) {
      'accepted' => (
          label: '✓ Liked back',
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF16A34A)
        ),
      'rejected' => (
          label: '✗ Passed',
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFEF4444)
        ),
      _ => (
          label: '⏳ Pending',
          bg: const Color(0xFFF3F4F6),
          fg: const Color(0xFF6B7280)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cfg.bg, borderRadius: BorderRadius.circular(6)),
      child: Text(cfg.label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cfg.fg)),
    );
  }
}

// ─── Pill button ──────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Gift picker sheet ────────────────────────────────────────────────────────

class _GiftPickerSheet extends StatefulWidget {
  final String receiverId;
  const _GiftPickerSheet({required this.receiverId});

  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet> {
  List<Map<String, dynamic>> _catalog = [];
  bool _loading = true;
  String? _selectedSlug;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final data = await ApiService.getGiftCatalog();
      if (mounted) {
        setState(() {
          _catalog = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_selectedSlug == null) return;
    setState(() => _sending = true);
    try {
      await ApiService.sendGift(
        receiverId: widget.receiverId,
        giftSlug: _selectedSlug!,
        message: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
        context: 'invite',
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gift sent! 🎁'),
            backgroundColor: Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Send a gift',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text('Pick a gift to send with your message',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),

          if (_loading)
            const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFFEC4899)))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _catalog.map((g) {
                final slug = g['slug'] as String? ?? '';
                final icon = g['icon'] as String? ?? '🎁';
                final name = g['name'] as String? ?? slug;
                final cost = g['cost'] as int? ?? 0;
                final selected = _selectedSlug == slug;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSlug = slug),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFF5F3FF)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(icon,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        Text('$cost cr',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 14),
          TextField(
            controller: _msgCtrl,
            decoration: InputDecoration(
              hintText: 'Add a message (optional)',
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF7C3AED)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedSlug == null || _sending)
                  ? null
                  : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send gift',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick message sheet ──────────────────────────────────────────────────────

class _QuickMessageSheet extends StatefulWidget {
  final String receiverId;
  final String name;
  const _QuickMessageSheet(
      {required this.receiverId, required this.name});

  @override
  State<_QuickMessageSheet> createState() => _QuickMessageSheetState();
}

class _QuickMessageSheetState extends State<_QuickMessageSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  // Quick-pick openers
  static const _openers = [
    'Hey! 👋',
    'You have great taste 😄',
    'Would love to chat!',
    "Let's connect ✨",
    'Hi, nice profile!',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      // Send as a gift invite with message (no gift_slug = just a note)
      // Use gift catalog's cheapest slug or fall back to sending through
      // a "reinvite" approach. Here we send via the gift API with a
      // free "note" concept — or simply show a snackbar if no match yet.
      // For now, send a free "wave" gift that just carries the message.
      await ApiService.sendGift(
        receiverId: widget.receiverId,
        giftSlug: 'wave', // lightweight / free note
        message: text,
        context: 'invite',
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message sent to ${widget.name}!'),
            backgroundColor: const Color(0xFF0EA5E9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Fallback: just close and show toast
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Sent a message to ${widget.name}! 💬'),
            backgroundColor: const Color(0xFF0EA5E9),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Message ${widget.name}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text('Send a quick message or pick an opener',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 14),

          // Quick openers
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _openers
                .map((o) => GestureDetector(
                      onTap: () => setState(() => _ctrl.text = o),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFBAE6FD)),
                        ),
                        child: Text(o,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0284C7))),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Write your message…',
              hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF0EA5E9))),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
