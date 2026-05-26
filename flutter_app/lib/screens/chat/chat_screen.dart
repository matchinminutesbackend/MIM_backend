import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../services/api_service.dart';
import '../../services/call_service.dart';
import '../../utils/time_utils.dart';
import '../profile/profile_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final MatchModel match;
  const ChatScreen({super.key, required this.match});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _hasText = false;
  int _prevMsgCount = 0;
  bool _removed = false; // true if partner removed match while chat is open
  Timer? _statusTimer;

  String get _myId => context.read<AuthProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _removed = widget.match.removedAt != null;
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      if (has) {
        context.read<MessagesProvider>().socket.sendTyping(widget.match.matchId);
      }
    });
    _loadMessages();
    // Poll every 30 s to detect live removal while the chat is open
    if (!_removed) {
      _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollMatchStatus());
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pollMatchStatus() async {
    if (!mounted || widget.match.matchId.isEmpty) return;
    try {
      final s = await ApiService.getMatchStatus(widget.match.matchId);
      if (!mounted) return;
      final isActive = s['is_active'] as bool? ?? true;
      if (!isActive && !_removed) setState(() => _removed = true);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    await context.read<MessagesProvider>().loadMessages(widget.match.matchId);
    await context.read<MessagesProvider>().markRead(widget.match.matchId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
  }

  void _scrollBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      await context.read<MessagesProvider>().sendMessage(widget.match.matchId, text);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    } catch (_) {
      _msgCtrl.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildRemovedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFFFFBEB),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'This match has ended. Send a new invite to reconnect.',
              style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              try {
                await ApiService.reinviteUser(widget.match.partnerId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Invite sent! 💌'),
                    backgroundColor: Color(0xFFEC4899),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Match Again',
                style: TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startCall(CallType type) {
    final call = context.read<CallService>();
    call.startCall(
      toPartnerId: widget.match.partnerId,
      toPartnerName: widget.match.partnerName,
      toPartnerPhoto: widget.match.partnerPhotoUrl,
      type: type,
      matchId: widget.match.matchId,
      socket: context.read<MessagesProvider>().socket,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_removed) _buildRemovedBanner(),
          Expanded(child: _buildMessages()),
          _buildTypingIndicator(),
          if (!_removed) _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleSpacing: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF374151)),
      onPressed: () => Navigator.pop(context),
    ),
    title: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(userId: widget.match.partnerId, matchId: widget.match.matchId),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFDE7F3),
                backgroundImage: widget.match.partnerPhotoUrl != null
                    ? CachedNetworkImageProvider(widget.match.partnerPhotoUrl!)
                    : null,
                child: widget.match.partnerPhotoUrl == null
                    ? Text(
                        widget.match.partnerName.isNotEmpty
                            ? widget.match.partnerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              if (widget.match.isOnline)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Consumer<MessagesProvider>(
              builder: (_, prov, __) {
                final typing = prov.isTyping(widget.match.matchId);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.match.partnerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: typing
                          ? const Text('typing…',
                              key: ValueKey('typing'),
                              style: TextStyle(fontSize: 11, color: Color(0xFFEC4899),
                                  fontStyle: FontStyle.italic))
                          : widget.match.isOnline
                              ? Row(
                                  key: const ValueKey('online'),
                                  children: [
                                    Container(width: 6, height: 6,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFF22C55E), shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    const Text('Online', style: TextStyle(fontSize: 11,
                                        color: Color(0xFF22C55E))),
                                  ],
                                )
                              : const SizedBox.shrink(key: ValueKey('offline')),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      // Voice call
      IconButton(
        icon: const Icon(Icons.call_outlined, color: Color(0xFF374151), size: 22),
        onPressed: () => _startCall(CallType.voice),
        tooltip: 'Voice call',
      ),
      // Video call
      IconButton(
        icon: const Icon(Icons.videocam_outlined, color: Color(0xFF374151), size: 22),
        onPressed: () => _startCall(CallType.video),
        tooltip: 'Video call',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFF374151)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (v) async {
          if (v == 'unmatch') {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Unmatch?'),
                content: Text(
                  'This will remove your match with ${widget.match.partnerName} and delete all messages.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
                  TextButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('Unmatch', style: TextStyle(color: Color(0xFFEF4444)))),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await ApiService.unmatch(widget.match.partnerId);
              Navigator.pop(context);
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'unmatch',
              child: Row(children: [
                Icon(Icons.person_remove_outlined, size: 18, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Text('Unmatch', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
              ])),
        ],
      ),
    ],
  );

  Widget _buildMessages() {
    return Consumer<MessagesProvider>(
      builder: (_, prov, __) {
        final msgs = prov.messagesFor(widget.match.matchId);

        // Auto-scroll when new messages arrive
        if (msgs.length > _prevMsgCount) {
          _prevMsgCount = msgs.length;
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
        }

        if (msgs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFBCFE8)),
                  ),
                  child: const Icon(Icons.favorite_rounded, size: 36, color: Color(0xFFEC4899)),
                ),
                const SizedBox(height: 16),
                Text('You matched with ${widget.match.partnerName}!',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: Color(0xFF111827))),
                const SizedBox(height: 6),
                const Text('Say hello and start the conversation',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ['👋 Hey!', '😊 Hi there!', '✨ You seem interesting!']
                      .map((s) => GestureDetector(
                            onTap: () {
                              _msgCtrl.text = s;
                              setState(() => _hasText = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4, offset: const Offset(0, 1)),
                                ],
                              ),
                              child: Text(s,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final msg = msgs[i];
            final isMe = msg.senderId == _myId;
            final showDate = i == 0 || !_sameDay(msgs[i - 1].sentAt, msg.sentAt);
            final showAvatar = !isMe &&
                (i == msgs.length - 1 || msgs[i + 1].senderId != msg.senderId);
            return Column(
              children: [
                if (showDate) _DateSeparator(dt: msg.sentAt),
                _Bubble(msg: msg, isMe: isMe, showAvatar: showAvatar),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Consumer<MessagesProvider>(
      builder: (_, prov, __) {
        final typing = prov.isTyping(widget.match.matchId);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: typing
              ? Container(
                  key: const ValueKey('typing'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFFDE7F3),
                        backgroundImage: widget.match.partnerPhotoUrl != null
                            ? CachedNetworkImageProvider(widget.match.partnerPhotoUrl!)
                            : null,
                        child: widget.match.partnerPhotoUrl == null
                            ? Text(
                                widget.match.partnerName.isNotEmpty
                                    ? widget.match.partnerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 10, color: Color(0xFFEC4899)))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18), topRight: Radius.circular(18),
                            bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06),
                                blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const _TypingDots(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showGifts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftSheet(
        match: widget.match,
        onSent: () {
          context.read<MessagesProvider>().loadMessages(widget.match.matchId);
        },
      ),
    );
  }

  Widget _buildInputBar() => Container(
    padding: EdgeInsets.only(
      left: 16, right: 12, top: 10,
      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Gift button
          GestureDetector(
            onTap: _showGifts,
            child: Container(
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFBCFE8)),
              ),
              child: const Center(
                child: Text('🎁', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _hasText || _sending
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: _send,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.4),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: _sending
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  )
                : Container(
                    key: const ValueKey('idle'),
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Color(0xFF9CA3AF), size: 20),
                  ),
          ),
        ],
      ),
    ),
  );
}

// ─── Sub widgets ──────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime dt;
  const _DateSeparator({required this.dt});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(_label(),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500)),
      ),
      const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
    ]),
  );
}

class _Bubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final bool showAvatar;
  const _Bubble({required this.msg, required this.isMe, required this.showAvatar});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: 2, bottom: 2,
      left: isMe ? 56 : 0,
      right: isMe ? 0 : 56,
    ),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) const SizedBox(width: 28),
        Flexible(
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFEC4899) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? const Color(0xFFEC4899).withOpacity(0.2)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 6, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF111827),
                    fontSize: 14, height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatTime(msg.sentAt),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.done_all,
                      size: 13,
                      color: msg.isRead
                          ? const Color(0xFFEC4899)
                          : const Color(0xFF9CA3AF),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Gift Sheet ───────────────────────────────────────────────────────────────

class _GiftSheet extends StatefulWidget {
  final MatchModel match;
  final VoidCallback onSent;
  const _GiftSheet({required this.match, required this.onSent});
  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _gifts = [];
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final results = await Future.wait([
        ApiService.getGiftCatalog(),
        ApiService.getWalletBalance(),
      ]);
      if (!mounted) return;
      setState(() {
        _gifts = (results[0] as List)
            .map((g) => Map<String, dynamic>.from(g as Map))
            .toList();
        _balance = ((results[1] as Map)['balance'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(Map<String, dynamic> gift) async {
    if (_sending) return;
    final cost = (gift['cost'] as num?)?.toInt() ?? 0;
    if (_balance < cost) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not enough credits. Buy more in the Credits tab.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService.sendGift(
        receiverId: widget.match.partnerId,
        giftSlug: gift['slug'] as String,
        context: 'chat',
        matchId: widget.match.matchId,
      );
      if (!mounted) return;
      widget.onSent();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${gift['name']} sent! 🎁'),
        backgroundColor: const Color(0xFF16A34A),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send gift: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text('Send a Gift',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFBCFE8)),
                  ),
                  child: Row(children: [
                    const Text('⚡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text('$_balance credits',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEC4899),
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          // Gift grid
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFFEC4899)),
            )
          else if (_gifts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No gifts available',
                  style: TextStyle(color: Color(0xFF9CA3AF))),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: _gifts.length,
                itemBuilder: (_, i) {
                  final gift = _gifts[i];
                  final cost = (gift['cost'] as num?)?.toInt() ?? 0;
                  final canAfford = _balance >= cost;
                  return GestureDetector(
                    onTap: _sending ? null : () => _send(gift),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: canAfford
                                ? const Color(0xFFFDF2F8)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: canAfford
                                  ? const Color(0xFFFBCFE8)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              gift['icon'] as String? ?? '🎁',
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gift['name'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 10,
                              color: canAfford
                                  ? const Color(0xFF374151)
                                  : const Color(0xFF9CA3AF)),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⚡',
                                style: TextStyle(fontSize: 9)),
                            Text(
                              '$cost',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: canAfford
                                      ? const Color(0xFFEC4899)
                                      : const Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
          final y = -4.0 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
          return Transform.translate(
            offset: Offset(0, y),
            child: Container(
              width: 7, height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                  color: Color(0xFF9CA3AF), shape: BoxShape.circle),
            ),
          );
        }),
      );
    },
  );
}
