import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/time_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _actioned = {}; // ids where accept/decline already tapped

  @override
  void initState() {
    super.initState();
    _load();
    NotificationService.clearBadge();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data
            .map((n) => Map<String, dynamic>.from(n as Map))
            .where((n) => n['is_read'] != true)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await ApiService.markAllNotificationsRead();
      if (mounted) setState(() => _notifications.clear());
    } catch (_) {}
  }

  Future<void> _markOne(String id) async {
    try {
      await ApiService.markNotificationRead(id);
      if (mounted) {
        setState(() => _notifications.removeWhere((n) => n['id'] == id));
      }
    } catch (_) {}
  }

  bool _isLikeType(Map<String, dynamic> notif) {
    final t = notif['type'] as String? ?? '';
    return t == 'like_received' || t == 'gift_like';
  }

  Future<void> _accept(Map<String, dynamic> notif) async {
    final id = notif['id'] as String;
    setState(() => _actioned.add(id));
    try {
      if (_isLikeType(notif)) {
        final actorId = (notif['actor'] as Map?)?['id'] as String?;
        if (actorId != null) await ApiService.likeUser(actorId);
        await _markOne(id); // marks + removes from list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Liked back! ❤️'),
            backgroundColor: Color(0xFFEC4899),
          ));
        }
      } else {
        await ApiService.acceptInvitation(id);
        await _markOne(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Invitation accepted! 🎉'),
            backgroundColor: Color(0xFF16A34A),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actioned.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  Future<void> _decline(Map<String, dynamic> notif) async {
    final id = notif['id'] as String;
    setState(() => _actioned.add(id));
    try {
      if (_isLikeType(notif)) {
        final actorId = (notif['actor'] as Map?)?['id'] as String?;
        if (actorId != null) await ApiService.rejectLiker(actorId);
        await _markOne(id); // marks + removes from list
      } else {
        await ApiService.declineInvitation(id);
        await _markOne(id);
      }
    } catch (e) {
      if (mounted) setState(() => _actioned.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(children: [
          const Text('Notifications',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAll,
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: Color(0xFFEC4899),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEC4899)))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFFEC4899),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) =>
                        _NotifTile(
                          notif: _notifications[i],
                          actioned: _actioned.contains(_notifications[i]['id']),
                          onTap: () => _markOne(_notifications[i]['id'] as String),
                          onAccept: () => _accept(_notifications[i]),
                          onDecline: () => _decline(_notifications[i]),
                        ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBCFE8)),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 36, color: Color(0xFFEC4899)),
            ),
            const SizedBox(height: 16),
            const Text('No notifications yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 6),
            const Text('You\'ll see likes, matches and messages here',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final bool actioned;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _NotifTile({
    required this.notif,
    required this.actioned,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  String get _type => notif['type'] as String? ?? '';
  bool get _isRead => notif['is_read'] as bool? ?? false;
  bool get _isReinvite => _type == 'reinvitation' || _type == 'reinvite';

  bool get _isGiftLike => _type == 'gift_like' || _type == 'like_received';

  bool get _isLikeAction => _type == 'like_received' || _type == 'gift_like';

  (IconData, Color, Color) get _iconStyle => switch (_type) {
        'gift_like' => (
            Icons.card_giftcard_rounded,
            const Color(0xFFFFFBEB),
            const Color(0xFFD97706),
          ),
        'liked_you' || 'like' || 'like_received' => (
            Icons.favorite_rounded,
            const Color(0xFFFDF2F8),
            const Color(0xFFEC4899),
          ),
        'match_created' || 'match' => (
            Icons.favorite_border_rounded,
            const Color(0xFFFDF2F8),
            const Color(0xFFEC4899),
          ),
        'message' || 'new_message' => (
            Icons.chat_bubble_outline_rounded,
            const Color(0xFFEFF6FF),
            const Color(0xFF3B82F6),
          ),
        'reinvitation' || 'reinvite' || 'match_invitation' => (
            Icons.refresh_rounded,
            const Color(0xFFFFFBEB),
            const Color(0xFFD97706),
          ),
        'gift' || 'gift_received' => (
            Icons.card_giftcard_rounded,
            const Color(0xFFF0FDF4),
            const Color(0xFF16A34A),
          ),
        'verification' || 'verified' => (
            Icons.verified_rounded,
            const Color(0xFFEFF6FF),
            const Color(0xFF3B82F6),
          ),
        'profile_view' => (
            Icons.visibility_rounded,
            const Color(0xFFF0FDF4),
            const Color(0xFF16A34A),
          ),
        _ => (
            Icons.notifications_rounded,
            const Color(0xFFF3F4F6),
            const Color(0xFF6B7280),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, bgColor, iconColor) = _iconStyle;
    final photoUrl = notif['sender_photo'] as String? ??
        notif['actor_photo'] as String?;
    final ts = notif['created_at'] as String?;

    String? giftMessage;
    if (_type == 'gift_like') {
      final payload = notif['payload'];
      if (payload is Map) giftMessage = payload['message'] as String?;
    }

    return GestureDetector(
      onTap: _isRead ? null : onTap,
      child: Container(
        color: _type == 'gift_like'
            ? (_isRead ? const Color(0xFFFFFBEB) : const Color(0xFFFEF3C7))
            : (_isRead ? Colors.white : const Color(0xFFFFF5F9)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar or icon
                Stack(
                  children: [
                    if (photoUrl != null)
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          width: 48, height: 48,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _IconAvatar(bgColor: bgColor, iconColor: iconColor, icon: icon),
                        ),
                      )
                    else
                      _IconAvatar(bgColor: bgColor, iconColor: iconColor, icon: icon),
                    // Type badge
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(icon, size: 10, color: iconColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif['title'] as String? ??
                            _defaultTitle(_type),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if ((notif['body'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          notif['body'] as String,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (giftMessage != null && giftMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFFDE68A), width: 1),
                          ),
                          child: Text(
                            '"$giftMessage"',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (ts != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatTs(ts),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isRead)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                        color: Color(0xFFEC4899), shape: BoxShape.circle),
                  ),
              ],
            ),

            // Accept / Decline for reinvitation
            if (_isReinvite && !actioned) ...[
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 60),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Decline',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      elevation: 0,
                    ),
                    child: const Text('Accept',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ] else if (_isReinvite && actioned) ...[
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 60),
                child: Text('Responded ✓',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ),
            ],

            // Like Back / Pass for like_received and gift_like
            if (_isLikeAction && !actioned) ...[
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 60),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Pass',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      elevation: 0,
                    ),
                    child: const Text('❤️ Like Back',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ] else if (_isLikeAction && actioned) ...[
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 60),
                child: Text('Responded ✓',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ),
            ],

            const Padding(
              padding: EdgeInsets.only(top: 12, left: 60),
              child: Divider(height: 1, color: Color(0xFFF3F4F6)),
            ),
          ],
        ),
      ),
    );
  }

  String _defaultTitle(String type) {
    final actorName = (notif['actor'] as Map?)?['name'] as String? ?? 'Someone';
    return switch (type) {
      'gift_like'      => '$actorName super liked you 🎁',
      'like_received'  => '$actorName liked you ❤️',
      'liked_you' || 'like' => '$actorName liked you ❤️',
      'match_created' || 'match' => 'You and $actorName matched! 🎉',
      'message' || 'new_message' => 'New message',
      'reinvitation' || 'reinvite' || 'match_invitation' => 'Invitation received',
      'gift' || 'gift_received' => 'You received a gift! 🎁',
      'verification' || 'verified' => 'Profile verified ✓',
      'profile_view' => '$actorName viewed your profile 👀',
      _ => 'New notification',
    };
  }

  String _formatTs(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return timeAgo(dt);
    } catch (_) {
      return '';
    }
  }
}

class _IconAvatar extends StatelessWidget {
  final Color bgColor;
  final Color iconColor;
  final IconData icon;
  const _IconAvatar(
      {required this.bgColor, required this.iconColor, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22),
      );
}
