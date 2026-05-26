import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../services/call_service.dart';

class CallOverlay extends StatelessWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallService>(
      builder: (_, call, __) {
        if (!call.isActive) return const SizedBox.shrink();

        // Incoming call → floating popup (not full-screen)
        if (call.state == CallState.ringing) {
          return _IncomingCallPopup(call: call);
        }

        // All other active states → full-screen overlay
        return Material(
          color: Colors.transparent,
          child: switch (call.state) {
            CallState.calling   => _OutgoingCall(call: call),
            CallState.connected => call.callType == CallType.video
                ? _VideoCall(call: call)
                : _AudioCall(call: call),
            CallState.ended     => _EndedCall(call: call),
            _                   => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

// ── Incoming call popup ────────────────────────────────────────────────────────

class _IncomingCallPopup extends StatefulWidget {
  final CallService call;
  const _IncomingCallPopup({required this.call});

  @override
  State<_IncomingCallPopup> createState() => _IncomingCallPopupState();
}

class _IncomingCallPopupState extends State<_IncomingCallPopup>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final isVideo = call.callType == CallType.video;

    return Material(
      color: Colors.black.withOpacity(0.55),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.2),
              end: Offset.zero,
            ).animate(_slideAnim),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row
                    Row(
                      children: [
                        // Pulsing avatar
                        _PulsingAvatar(
                          photo: call.partnerPhoto,
                          name: call.partnerName ?? '',
                          controller: _pulseCtrl,
                          isVideo: isVideo,
                        ),
                        const SizedBox(width: 16),
                        // Name + call type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                call.partnerName ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isVideo ? Icons.videocam : Icons.call,
                                    color: const Color(0xFF22C55E),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isVideo
                                        ? 'Incoming video call'
                                        : 'Incoming voice call',
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        // Decline
                        Expanded(
                          child: GestureDetector(
                            onTap: call.declineCall,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFEF4444).withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.call_end_rounded,
                                      color: Color(0xFFEF4444), size: 22),
                                  SizedBox(width: 8),
                                  Text('Decline',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Accept
                        Expanded(
                          child: GestureDetector(
                            onTap: () => call.acceptCall(),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Accept',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingAvatar extends StatelessWidget {
  final String? photo;
  final String name;
  final AnimationController controller;
  final bool isVideo;
  const _PulsingAvatar({
    required this.photo,
    required this.name,
    required this.controller,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final pulse = (controller.value < 0.5)
            ? controller.value * 2
            : (1 - controller.value) * 2;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Container(
              width: 74 + pulse * 14,
              height: 74 + pulse * 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withOpacity(0.12 * (1 - pulse * 0.5)),
              ),
            ),
            // Middle pulse ring
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E)
                    .withOpacity(0.18 * (1 - pulse * 0.3)),
              ),
            ),
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF22C55E), width: 2.5),
              ),
              child: ClipOval(
                child: photo != null
                    ? CachedNetworkImage(
                        imageUrl: photo!, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFF312E81),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            // Video/voice icon badge
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Outgoing call ─────────────────────────────────────────────────────────────

class _OutgoingCall extends StatelessWidget {
  final CallService call;
  const _OutgoingCall({required this.call});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                _Avatar(photo: call.partnerPhoto, name: call.partnerName ?? '', size: 96),
                const SizedBox(height: 16),
                Text(call.partnerName ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const _PulsingText('Calling…'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: _CircleBtn(
                icon: Icons.call_end,
                color: const Color(0xFFEF4444),
                label: 'Cancel',
                onTap: call.hangup,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active audio call ─────────────────────────────────────────────────────────

class _AudioCall extends StatelessWidget {
  final CallService call;
  const _AudioCall({required this.call});

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                _Avatar(photo: call.partnerPhoto, name: call.partnerName ?? '', size: 96),
                const SizedBox(height: 16),
                Text(call.partnerName ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_fmt(call.durationSeconds),
                    style: const TextStyle(color: Color(0xFF22C55E), fontSize: 16)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CircleBtn(
                        icon: call.isMuted ? Icons.mic_off : Icons.mic,
                        color: call.isMuted ? Colors.white : Colors.white24,
                        iconColor: call.isMuted ? Colors.black : Colors.white,
                        label: call.isMuted ? 'Unmute' : 'Mute',
                        onTap: call.toggleMute,
                        small: true,
                      ),
                      _CircleBtn(
                        icon: Icons.call_end,
                        color: const Color(0xFFEF4444),
                        label: 'End',
                        onTap: call.hangup,
                      ),
                      _CircleBtn(
                        icon: Icons.speaker,
                        color: Colors.white24,
                        label: 'Speaker',
                        onTap: () {},
                        small: true,
                      ),
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

// ── Active video call ─────────────────────────────────────────────────────────

class _VideoCall extends StatelessWidget {
  final CallService call;
  const _VideoCall({required this.call});

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: RTCVideoView(
            call.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
        // Dark overlay top
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ),
            ),
          ),
        ),
        // Timer top center
        Positioned(
          top: 48, left: 0, right: 0,
          child: Center(
            child: Text(_fmt(call.durationSeconds),
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
        // Local video (PiP bottom-right)
        Positioned(
          right: 16, bottom: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 90, height: 130,
              child: RTCVideoView(call.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          ),
        ),
        // Controls bottom
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                top: 16, left: 24, right: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CircleBtn(
                  icon: call.isMuted ? Icons.mic_off : Icons.mic,
                  color: call.isMuted ? Colors.white : Colors.white24,
                  iconColor: call.isMuted ? Colors.black : Colors.white,
                  label: call.isMuted ? 'Unmute' : 'Mute',
                  onTap: call.toggleMute,
                  small: true,
                ),
                _CircleBtn(
                  icon: Icons.call_end,
                  color: const Color(0xFFEF4444),
                  label: 'End',
                  onTap: call.hangup,
                ),
                _CircleBtn(
                  icon: call.isCameraOff ? Icons.videocam_off : Icons.videocam,
                  color: call.isCameraOff ? Colors.white : Colors.white24,
                  iconColor: call.isCameraOff ? Colors.black : Colors.white,
                  label: call.isCameraOff ? 'Camera On' : 'Camera Off',
                  onTap: call.toggleCamera,
                  small: true,
                ),
                _CircleBtn(
                  icon: Icons.flip_camera_ios,
                  color: Colors.white24,
                  label: 'Flip',
                  onTap: call.switchCamera,
                  small: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Call ended ────────────────────────────────────────────────────────────────

class _EndedCall extends StatelessWidget {
  final CallService call;
  const _EndedCall({required this.call});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_end, color: Color(0xFFEF4444), size: 56),
            SizedBox(height: 16),
            Text('Call Ended', style: TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool small;

  const _CircleBtn({
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
    required this.label,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 52.0 : 64.0;
    final iconSize = small ? 22.0 : 28.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photo;
  final String name;
  final double size;
  const _Avatar({this.photo, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 3),
      ),
      child: ClipOval(
        child: photo != null
            ? CachedNetworkImage(imageUrl: photo!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFFDE7F3),
                child: Center(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold,
                          color: const Color(0xFFEC4899))),
                ),
              ),
      ),
    );
  }
}

class _PulsingText extends StatefulWidget {
  final String text;
  const _PulsingText(this.text);

  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Text(widget.text,
            style: const TextStyle(color: Colors.white60, fontSize: 15)),
      );
}
