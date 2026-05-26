import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';

class MessagesProvider extends ChangeNotifier {
  final SocketService socket = SocketService();

  List<MatchModel> _matches = [];
  List<MatchModel> _conversations = [];
  final Map<String, List<MessageModel>> _messages = {};
  bool _matchesLoading = false;
  bool _convLoading = false;
  int _totalUnread = 0;

  // Typing: matchId → isTyping
  final Map<String, bool> _typing = {};
  final Map<String, Timer> _typingTimers = {};

  List<MatchModel> get matches => _matches;
  List<MatchModel> get conversations => _conversations;
  bool get matchesLoading => _matchesLoading;
  bool get convLoading => _convLoading;
  int get totalUnread => _totalUnread;

  List<MessageModel> messagesFor(String matchId) => _messages[matchId] ?? [];
  bool isTyping(String matchId) => _typing[matchId] ?? false;

  static int _byRecent(MatchModel a, MatchModel b) {
    final at = a.lastMessageAt ?? a.matchedAt ?? DateTime(2000);
    final bt = b.lastMessageAt ?? b.matchedAt ?? DateTime(2000);
    return bt.compareTo(at);
  }

  void connectSocket(String userId) {
    socket.connect();

    socket.on('new_message', (data) {
      if (data is! Map) return;
      final matchId = data['match_id']?.toString();
      final raw = data['message'];
      if (matchId == null || raw == null || raw is! Map) return;
      final msgData = Map<String, dynamic>.from(raw as Map);
      final msg = MessageModel.fromJson(msgData);
      final list = _messages.putIfAbsent(matchId, () => []);
      // Skip if already added optimistically by sendMessage
      if (list.any((m) => m.id == msg.id)) return;
      list.add(msg);

      final idx = _conversations.indexWhere((c) => c.matchId == matchId);
      if (idx != -1) {
        if (msg.senderId != userId) {
          _conversations[idx].unreadCount++;
          _totalUnread++;
          // Show a system notification banner for the incoming message.
          final senderName = _conversations[idx].partnerName;
          final body = msg.content.length > 100
              ? '${msg.content.substring(0, 100)}…'
              : msg.content;
          NotificationService.showLocalNotification(
            title: '$senderName 💬',
            body: body,
            payload: {'type': 'new_message', 'match_id': matchId},
          );
        }
        _conversations[idx].lastMessage = msg.content;
        _conversations[idx].lastMessageAt = msg.sentAt;
        _conversations.sort(_byRecent);
      }
      notifyListeners();
    });

    socket.on('typing', (data) {
      final matchId = data['match_id'] as String?;
      final fromId = data['user_id'] as String?;
      if (matchId == null || fromId == userId) return;
      _typing[matchId] = true;
      _typingTimers[matchId]?.cancel();
      _typingTimers[matchId] = Timer(const Duration(seconds: 3), () {
        _typing[matchId] = false;
        notifyListeners();
      });
      notifyListeners();
    });

    socket.on('messages_read', (data) {
      if (data is! Map) return;
      final matchId = data['match_id'] as String?;
      if (matchId == null) return;
      final msgs = _messages[matchId];
      if (msgs != null) {
        for (final m in msgs) {
          m.isRead = true;
        }
      }
      notifyListeners();
    });

    socket.on('match_created', (_) => loadMatches());
    socket.on('match_removed', (data) {
      final matchId = data['match_id'] as String?;
      if (matchId == null) return;
      _matches.removeWhere((m) => m.matchId == matchId);
      _conversations.removeWhere((c) => c.matchId == matchId);
      notifyListeners();
    });
  }

  Future<void> loadMatches() async {
    _matchesLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getMyMatches();
      _matches = data.map((j) => MatchModel.fromJson(j)).toList();
    } catch (_) {}
    _matchesLoading = false;
    notifyListeners();
  }

  Future<void> loadConversations() async {
    _convLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getConversations();
      _conversations = data.map((j) => MatchModel.fromJson(j)).toList();
      _conversations.sort(_byRecent);
      _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } catch (_) {}
    _convLoading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String matchId) async {
    try {
      final data = await ApiService.getMessageHistory(matchId);
      final seen = <String>{};
      final msgs = <MessageModel>[];
      for (final j in data) {
        final m = MessageModel.fromJson(j);
        if (seen.add(m.id)) msgs.add(m);
      }
      _messages[matchId] = msgs;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendMessage(String matchId, String text) async {
    final data = await ApiService.sendMessage(matchId, text);
    final msg = MessageModel.fromJson(data);
    final list = _messages.putIfAbsent(matchId, () => []);
    // Guard: socket may have already inserted this message before the REST
    // call returned (race condition where socket fires before HTTP response).
    if (!list.any((m) => m.id == msg.id)) {
      list.add(msg);
    }
    final idx = _conversations.indexWhere((c) => c.matchId == matchId);
    if (idx != -1) {
      _conversations[idx].lastMessage = text;
      _conversations[idx].lastMessageAt = msg.sentAt;
      _conversations.sort(_byRecent);
    }
    notifyListeners();
  }

  Future<void> markRead(String matchId) async {
    try {
      await ApiService.markMessagesRead(matchId);
      final idx = _conversations.indexWhere((c) => c.matchId == matchId);
      if (idx != -1) {
        _totalUnread -= _conversations[idx].unreadCount;
        _conversations[idx].unreadCount = 0;
        if (_totalUnread < 0) _totalUnread = 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final t in _typingTimers.values) { t.cancel(); }
    socket.disconnect();
    super.dispose();
  }
}
