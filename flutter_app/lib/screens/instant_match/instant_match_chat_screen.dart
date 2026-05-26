import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messages_provider.dart';
import '../../services/api_service.dart';

class InstantMatchChatScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> partner;

  const InstantMatchChatScreen({
    super.key,
    required this.matchId,
    required this.partner,
  });

  @override
  State<InstantMatchChatScreen> createState() => _InstantMatchChatScreenState();
}

class _InstantMatchChatScreenState extends State<InstantMatchChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _hasText = false;

  // Chat status
  bool _ended = false;
  String? _inviteStatus; // null | 'sent' | 'received'
  bool _actioning = false;

  Timer? _statusTimer;
  List<MessageModel> _messages = [];
  bool _msgsLoading = true;

  String get _myId => context.read<AuthProvider>().user?.id ?? '';
  String get _partnerName => widget.partner['name'] as String? ?? 'Match';
  String? get _partnerPhoto => widget.partner['main_image_url'] as String?;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _loadMessages();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ApiService.getMessageHistory(widget.matchId);
      if (!mounted) return;
      setState(() {
        _messages = msgs.map((m) => MessageModel.fromJson(m)).toList();
        _msgsLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _msgsLoading = false);
    }
  }

  Future<void> _pollStatus() async {
    try {
      final s = await ApiService.instantMatchChatStatus(widget.matchId);
      if (!mounted) return;
      final ended = s['ended'] == true;
      final inviteStatus = s['invite_status'] as String?;

      // New messages via socket are handled by MessagesProvider — just poll for status
      setState(() {
        _ended = ended;
        _inviteStatus = inviteStatus;
      });

      if (ended && !_ended) {
        _statusTimer?.cancel();
        _showEndedDialog();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final sent = await ApiService.sendMessage(widget.matchId, text);
      if (!mounted) return;
      setState(() {
        _messages.add(MessageModel.fromJson(sent));
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leaveChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Leave chat?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'The chat will end for both of you. You can invite them to connect before leaving.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try { await ApiService.instantMatchChatLeave(widget.matchId); } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendInvite() async {
    setState(() => _actioning = true);
    try {
      await ApiService.instantMatchChatInvite(widget.matchId);
      if (mounted) setState(() { _inviteStatus = 'sent'; _actioning = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _actioning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  Future<void> _acceptInvite() async {
    setState(() => _actioning = true);
    try {
      await ApiService.instantMatchChatAccept(widget.matchId);
      if (!mounted) return;
      setState(() { _actioning = false; _inviteStatus = null; });
      _statusTimer?.cancel();
      // Chat is now permanent — pop back to main and notify
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You are now connected! 🎉 Find them in Messages.'),
        backgroundColor: Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ));
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _actioning = false);
    }
  }

  Future<void> _declineInvite() async {
    setState(() => _actioning = true);
    try {
      await ApiService.instantMatchChatDecline(widget.matchId);
      if (mounted) setState(() { _inviteStatus = null; _actioning = false; });
    } catch (_) {
      if (mounted) setState(() => _actioning = false);
    }
  }

  void _showEndedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Chat ended', style: TextStyle(color: Colors.white)),
        content: const Text(
          'The other person has left. The chat is now closed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Temp banner
          if (!_ended) _buildTempBanner(),
          // Invite received banner
          if (_inviteStatus == 'received') _buildInviteReceivedBanner(),
          // Invite sent banner
          if (_inviteStatus == 'sent') _buildInviteSentBanner(),
          // Chat ended banner
          if (_ended) _buildEndedBanner(),
          // Messages
          Expanded(child: _buildMessages()),
          // Input
          if (!_ended) _buildInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFF1A0A1E),
    elevation: 0,
    leading: IconButton(
      onPressed: _leaveChat,
      icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
    ),
    title: Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 36, height: 36,
            child: _partnerPhoto != null
                ? CachedNetworkImage(imageUrl: _partnerPhoto!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarFallback())
                : _avatarFallback(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_partnerName,
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Text('Instant Match · Temporary',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
    actions: [
      if (!_ended && _inviteStatus == null)
        TextButton.icon(
          onPressed: _actioning ? null : _sendInvite,
          icon: const Icon(Icons.person_add_outlined, size: 16, color: Color(0xFF8B5CF6)),
          label: const Text('Connect', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 13)),
        ),
    ],
  );

  Widget _avatarFallback() => Container(
    color: const Color(0xFF2D1B33),
    child: Center(
      child: Text(
        _partnerName.isNotEmpty ? _partnerName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget _buildTempBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFF8B5CF6).withOpacity(0.15),
    child: Row(children: [
      const Icon(Icons.bolt_rounded, color: Color(0xFF8B5CF6), size: 16),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Temporary chat — tap Connect to add to friends',
          style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12),
        ),
      ),
    ]),
  );

  Widget _buildInviteReceivedBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: const Color(0xFF16A34A).withOpacity(0.15),
    child: Row(children: [
      const Icon(Icons.person_add, color: Color(0xFF4ADE80), size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text('$_partnerName wants to connect!',
            style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
      if (!_actioning) ...[
        TextButton(
          onPressed: _declineInvite,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Decline', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: _acceptInvite,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Accept', style: TextStyle(fontSize: 12, color: Colors.white)),
        ),
      ] else
        const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4ADE80))),
    ]),
  );

  Widget _buildInviteSentBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFFF59E0B).withOpacity(0.15),
    child: const Row(children: [
      Icon(Icons.hourglass_top_rounded, color: Color(0xFFFBBF24), size: 16),
      SizedBox(width: 8),
      Text('Connection request sent — waiting for response',
          style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12)),
    ]),
  );

  Widget _buildEndedBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: const Color(0xFFEF4444).withOpacity(0.15),
    child: const Row(children: [
      Icon(Icons.info_outline_rounded, color: Color(0xFFF87171), size: 16),
      SizedBox(width: 8),
      Text('This chat has ended', style: TextStyle(color: Color(0xFFF87171), fontSize: 12)),
    ]),
  );

  Widget _buildMessages() {
    if (_msgsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            Text('Say hi to $_partnerName!',
                style: const TextStyle(color: Colors.white30, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(
        msg: _messages[i],
        isMe: _messages[i].senderId == _myId,
      ),
    );
  }

  Widget _buildInput() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: const BoxDecoration(
      color: Color(0xFF1A0A1E),
      border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
    ),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: _msgCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Type a message…',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: (_hasText && !_sending) ? _send : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: (_hasText && !_sending)
                ? const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  )
                : null,
            color: (!_hasText || _sending) ? Colors.white12 : null,
          ),
          child: _sending
              ? const Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : Icon(Icons.send_rounded,
                  color: _hasText ? Colors.white : Colors.white30, size: 20),
        ),
      ),
    ]),
  );
}

// ─── Message bubble ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                )
              : null,
          color: isMe ? null : Colors.white12,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Text(
          msg.content,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}
