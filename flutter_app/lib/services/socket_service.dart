import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

typedef SocketHandler = void Function(Map<String, dynamic> data);

class SocketService {
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  int _reconnectDelay = 1;
  String? _token;

  final Map<String, List<SocketHandler>> _handlers = {};

  void on(String event, SocketHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event) => _handlers.remove(event);

  Future<void> connect() async {
    _token = await StorageService.getToken();
    if (_token == null) return;
    _intentionalClose = false;
    _establish();
  }

  void _establish() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${ApiConfig.wsUrl}/ws/chat?token=$_token'),
      );
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
        cancelOnError: false,
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _rawSend({'type': 'ping'});
      });
      _reconnectDelay = 1;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      if (type == null || type == 'pong' || type == 'connected') return;
      final listeners = _handlers[type] ?? [];
      for (final h in listeners) {
        h(msg);
      }
      // wildcard
      for (final h in _handlers['*'] ?? []) {
        h(msg);
      }
    } catch (_) {}
  }

  void _onDisconnect() {
    _pingTimer?.cancel();
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(1, 32);
      _establish();
    });
  }

  void _rawSend(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void send(Map<String, dynamic> data) => _rawSend(data);

  void sendTyping(String matchId) => _rawSend({'type': 'typing', 'match_id': matchId});

  void disconnect() {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close(4401);
    _channel = null;
  }
}
