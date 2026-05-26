import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class BannedScreen extends StatefulWidget {
  final String reason;
  final DateTime? expiresAt;

  const BannedScreen({super.key, required this.reason, this.expiresAt});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.expiresAt != null) {
      _updateRemaining();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    }
  }

  void _updateRemaining() {
    final diff = widget.expiresAt!.toUtc().difference(DateTime.now().toUtc());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final isPermanent = widget.expiresAt == null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon badge
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.20),
                    blurRadius: 24, offset: const Offset(0, 8),
                  )],
                ),
                child: const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 42),
              ),
              const SizedBox(height: 24),

              const Text('Account Suspended',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                      color: Color(0xFF111827), letterSpacing: -0.3)),
              const SizedBox(height: 8),
              const Text('Your account has been suspended by our moderation team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
              const SizedBox(height: 24),

              // Reason card
              _Card(
                borderColor: const Color(0xFFFECACA),
                color: Colors.white,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('REASON', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444), letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(widget.reason, style: const TextStyle(
                      fontSize: 14, color: Color(0xFF374151), height: 1.5)),
                ]),
              ),
              const SizedBox(height: 10),

              // Expiry card — static for permanent, countdown for temp
              if (isPermanent)
                _Card(
                  borderColor: const Color(0xFFFECACA),
                  color: const Color(0xFFFEF2F2),
                  child: Row(children: const [
                    Icon(Icons.block_rounded, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('This ban is permanent.',
                          style: TextStyle(fontSize: 13, height: 1.4,
                              fontWeight: FontWeight.w500, color: Color(0xFFB91C1C))),
                    ),
                  ]),
                )
              else ...[
                _Card(
                  borderColor: const Color(0xFFFED7AA),
                  color: const Color(0xFFFFF7ED),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFF97316)),
                      const SizedBox(width: 6),
                      Text(
                        'Reinstated on ${_fmt(widget.expiresAt!)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFEA580C),
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // Live countdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CountdownUnit(value: _remaining.inDays, label: 'DAYS'),
                        _CountdownDot(),
                        _CountdownUnit(value: _remaining.inHours.remainder(24), label: 'HRS'),
                        _CountdownDot(),
                        _CountdownUnit(value: _remaining.inMinutes.remainder(60), label: 'MIN'),
                        _CountdownDot(),
                        _CountdownUnit(value: _remaining.inSeconds.remainder(60), label: 'SEC'),
                      ],
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 24),

              const Text('Think this is a mistake? Contact us at\nsupport@lazyrabbit.in',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.5)),
              const SizedBox(height: 28),

              // Sign out
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                  },
                  child: const Text('Sign Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 52, height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Center(
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: Color(0xFFEA580C), letterSpacing: 1,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w600, letterSpacing: 1)),
    ],
  );
}

class _CountdownDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 18),
    child: Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
        color: Color(0xFFEA580C))),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color color;
  const _Card({required this.child, required this.borderColor, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}
