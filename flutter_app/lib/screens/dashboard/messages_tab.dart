import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_model.dart';
import '../../providers/messages_provider.dart';
import '../../services/api_service.dart';
import '../../utils/time_utils.dart';
import '../chat/chat_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_detail_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  int _notifUnread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagesProvider>().loadConversations();
      _loadNotifCount();
    });
  }

  Future<void> _loadNotifCount() async {
    try {
      final data = await ApiService.getUnreadCount();
      if (mounted) setState(() => _notifUnread = (data['count'] as num?)?.toInt() ?? 0);
    } catch (_) {}
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
          'Messages',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Color(0xFF374151), size: 24),
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()));
                  _loadNotifCount(); // refresh badge on return
                },
              ),
              if (_notifUnread > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Color(0xFFEC4899), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        _notifUnread > 9 ? '9+' : '$_notifUnread',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: Consumer<MessagesProvider>(
        builder: (_, provider, __) {
          if (provider.convLoading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)));
          }
          if (provider.conversations.isEmpty) {
            return _EmptyState();
          }
          return RefreshIndicator(
            color: const Color(0xFFEC4899),
            onRefresh: provider.loadConversations,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.conversations.length,
              itemBuilder: (_, i) => _ConversationTile(match: provider.conversations[i]),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBCFE8)),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Color(0xFFEC4899)),
            ),
            const SizedBox(height: 16),
            const Text('No conversations yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            const Text('Match with someone to start chatting',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _ConversationTile extends StatelessWidget {
  final MatchModel match;
  const _ConversationTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final hasUnread = match.unreadCount > 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(match: match)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            // Avatar — tap to view profile
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileDetailScreen(userId: match.partnerId, matchId: match.matchId),
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: hasUnread
                          ? Border.all(color: const Color(0xFFEC4899), width: 2)
                          : Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    ),
                    child: ClipOval(
                      child: match.partnerPhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: match.partnerPhotoUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _InitialAvatar(name: match.partnerName),
                            )
                          : _InitialAvatar(name: match.partnerName),
                    ),
                  ),
                  // Online indicator — only shown when partner is actually online
                  if (match.isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.partnerName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (match.lastMessageAt != null || match.matchedAt != null)
                        Text(
                          timeAgo(match.lastMessageAt ?? match.matchedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: hasUnread ? const Color(0xFFEC4899) : const Color(0xFF9CA3AF),
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.lastMessage ?? 'Say hello! 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${match.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
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

class _InitialAvatar extends StatelessWidget {
  final String name;
  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFDE7F3),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFEC4899)),
          ),
        ),
      );
}
