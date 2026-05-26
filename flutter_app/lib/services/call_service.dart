import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';
import 'socket_service.dart';

enum CallState { idle, calling, ringing, connected, ended }
enum CallType { voice, video }

class CallService extends ChangeNotifier {
  CallState _state = CallState.idle;
  CallType _callType = CallType.voice;
  String? partnerId;
  String? partnerName;
  String? partnerPhoto;
  bool isCaller = false;
  bool isMuted = false;
  bool isCameraOff = false;
  int durationSeconds = 0;

  String? _matchId;

  CallState get state => _state;
  CallType get callType => _callType;
  bool get isActive => _state != CallState.idle && _state != CallState.ended;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  SocketService? _socket;

  Timer? _ringTimer;
  Timer? _durationTimer;
  final List<RTCIceCandidate> _pendingCandidates = [];

  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> init() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  // ── Outgoing call ──────────────────────────────────────────────────────────

  Future<void> startCall({
    required String toPartnerId,
    required String toPartnerName,
    required String? toPartnerPhoto,
    required CallType type,
    required SocketService socket,
    String? matchId,
  }) async {
    if (_state != CallState.idle) return;
    _socket = socket;
    partnerId = toPartnerId;
    partnerName = toPartnerName;
    partnerPhoto = toPartnerPhoto;
    _callType = type;
    _matchId = matchId;
    isCaller = true;
    isMuted = false;
    isCameraOff = false;

    _setState(CallState.calling);

    socket.send({
      'type': 'call_invite',
      'to': toPartnerId,
      'match_id': matchId,
      'call_type': type == CallType.video ? 'video' : 'voice',
    });

    // Auto-cancel if no answer in 35s
    _ringTimer = Timer(const Duration(seconds: 35), () => hangup());
  }

  // ── Incoming call ──────────────────────────────────────────────────────────

  void onIncomingCall(Map<String, dynamic> data) {
    if (_state != CallState.idle) {
      _socket?.send({'type': 'call_decline', 'to': data['from'], 'reason': 'busy'});
      return;
    }
    partnerId = data['from'] as String?;
    partnerName = data['caller_name'] as String? ?? 'Unknown';
    partnerPhoto = data['caller_photo'] as String?;
    _matchId = data['match_id'] as String?;
    _callType = data['call_type'] == 'video' ? CallType.video : CallType.voice;
    isCaller = false;
    isMuted = false;
    isCameraOff = false;
    _setState(CallState.ringing);

    _ringTimer = Timer(const Duration(seconds: 35), () => _handleMissed());
  }

  Future<void> acceptCall() async {
    if (_state != CallState.ringing) return;
    _ringTimer?.cancel();
    _socket?.send({'type': 'call_accept', 'to': partnerId});
    await _initMedia();
    _setState(CallState.connected);
    _startDurationTimer();
  }

  void declineCall() {
    if (_state != CallState.ringing) return;
    _ringTimer?.cancel();
    _socket?.send({'type': 'call_decline', 'to': partnerId, 'reason': 'declined'});
    _reset();
  }

  // ── Signaling handlers (called by DashboardScreen socket listener) ─────────

  Future<void> onCallAccepted(Map<String, dynamic> data) async {
    if (_state != CallState.calling) return;
    _ringTimer?.cancel();
    await _initMedia();
    await _createPeerConnection();
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _socket?.send({
      'type': 'call_offer',
      'to': partnerId,
      'sdp': offer.sdp,
    });
    _setState(CallState.connected);
    _startDurationTimer();
  }

  Future<void> onCallOffer(Map<String, dynamic> data) async {
    await _createPeerConnection();
    await _pc!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, 'offer'),
    );
    for (final c in _pendingCandidates) {
      await _pc!.addCandidate(c);
    }
    _pendingCandidates.clear();
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _socket?.send({
      'type': 'call_answer',
      'to': partnerId,
      'sdp': answer.sdp,
    });
  }

  Future<void> onCallAnswer(Map<String, dynamic> data) async {
    await _pc?.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, 'answer'),
    );
    for (final c in _pendingCandidates) {
      await _pc!.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  Future<void> onIceCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String,
      data['sdpMid'] as String? ?? '',
      data['sdpMLineIndex'] as int? ?? 0,
    );
    if (_pc != null) {
      await _pc!.addCandidate(candidate);
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  void onCallDeclined(Map<String, dynamic> data) {
    _ringTimer?.cancel();
    _setState(CallState.ended);
    Future.delayed(const Duration(seconds: 2), _reset);
  }

  void onCallHangup(Map<String, dynamic> data) {
    _ringTimer?.cancel();
    _durationTimer?.cancel();
    _setState(CallState.ended);
    Future.delayed(const Duration(seconds: 2), _reset);
  }

  void onCallError(Map<String, dynamic> data) {
    _ringTimer?.cancel();
    _reset();
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  void hangup() {
    _ringTimer?.cancel();
    _durationTimer?.cancel();
    _socket?.send({'type': 'call_hangup', 'to': partnerId, 'duration': durationSeconds});
    _logCallSummary(missed: false);
    _setState(CallState.ended);
    Future.delayed(const Duration(seconds: 2), _reset);
  }

  void toggleMute() {
    isMuted = !isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !isMuted);
    notifyListeners();
  }

  void toggleCamera() {
    isCameraOff = !isCameraOff;
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !isCameraOff);
    notifyListeners();
  }

  void switchCamera() {
    _localStream?.getVideoTracks().forEach((t) => Helper.switchCamera(t));
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _initMedia() async {
    final constraints = {
      'audio': true,
      'video': _callType == CallType.video
          ? {'width': 640, 'height': 480, 'facingMode': 'user'}
          : false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;
    notifyListeners();
  }

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_iceConfig);
    _localStream?.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

    _pc!.onIceCandidate = (candidate) {
      _socket?.send({
        'type': 'call_ice',
        'to': partnerId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
        notifyListeners();
      }
    };
  }

  void _handleMissed() {
    if (_state == CallState.ringing) {
      _socket?.send({'type': 'call_hangup', 'to': partnerId, 'reason': 'missed'});
      _logCallSummary(missed: true);
      _reset();
    }
  }

  void _logCallSummary({required bool missed}) {
    final mid = _matchId;
    if (mid == null || mid.isEmpty) return;
    // Only log if call was actually connected (or missed on callee side)
    if (!missed && durationSeconds == 0) return;
    ApiService.logCallSummary(
      mid,
      media: _callType == CallType.video ? 'video' : 'audio',
      durationSeconds: durationSeconds,
      missed: missed,
    );
  }

  void _startDurationTimer() {
    durationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      durationSeconds++;
      notifyListeners();
    });
  }

  void _setState(CallState s) {
    _state = s;
    notifyListeners();
  }

  void _reset() {
    _matchId = null;
    _pc?.close();
    _pc = null;
    _localStream?.dispose();
    _localStream = null;
    _remoteStream?.dispose();
    _remoteStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _pendingCandidates.clear();
    partnerId = null;
    partnerName = null;
    partnerPhoto = null;
    durationSeconds = 0;
    isMuted = false;
    isCameraOff = false;
    _state = CallState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _pc?.close();
    _ringTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}
