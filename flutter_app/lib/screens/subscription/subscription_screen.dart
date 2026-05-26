import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedTier = 'plus';
  String? _selectedSlug;
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  bool _purchasing = false;
  String? _error;
  String? _currentPlan;
  String? _currentTier;

  late final Razorpay _razorpay;
  Map<String, dynamic>? _pendingOrder;

  static const _plusFeatures = [
    (Icons.favorite,       'Unlimited hearts'),
    (Icons.swipe,          'Unlimited passes'),
    (Icons.visibility,     'See who liked you'),
    (Icons.trending_up,    'Priority in discovery'),
    (Icons.block,          'Ad-free experience'),
  ];

  static const _proFeatures = [
    (Icons.star,           'Everything in Plus'),
    (Icons.call,           'Voice calls'),
    (Icons.videocam,       'Video calls'),
    (Icons.done_all,       'Read receipts'),
    (Icons.bolt,           'Profile boost (1/week)'),
  ];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
      setState(() { _purchasing = false; _pendingOrder = null; });
    });
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getSubscriptionPlans(),
        ApiService.getMySubscription(),
      ]);
      final body = results[0] as Map<String, dynamic>;
      final sub = results[1] as Map<String, dynamic>;

      final plans = (body['plans'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final currentTier = sub['tier'] as String?;
      final tier = (currentTier == 'pro') ? 'pro' : 'plus';

      setState(() {
        _plans = plans;
        _currentPlan = sub['plan'] as String?;
        _currentTier = currentTier;
        _selectedTier = tier;
        _selectedSlug = _tierPlans(tier)
            .firstWhere((p) => p['months'] == 1, orElse: () => {})['slug'] as String?;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _tierPlans(String tier) {
    final list = _plans.where((p) => p['tier'] == tier).toList();
    list.sort((a, b) => (a['months'] as int).compareTo(b['months'] as int));
    return list;
  }

  void _switchTier(String tier) {
    setState(() {
      _selectedTier = tier;
      _selectedSlug = _tierPlans(tier)
          .firstWhere((p) => p['months'] == 1, orElse: () => {})['slug'] as String?;
    });
  }

  Future<void> _subscribe() async {
    if (_selectedSlug == null || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      final order = await ApiService.createSubscriptionOrder(_selectedSlug!);
      _pendingOrder = order;
      _razorpay.open({
        'key': order['key_id'],
        'amount': order['amount_paise'],
        'currency': 'INR',
        'name': 'MatchInMinutes',
        'description': _selectedSlug!.replaceAll('_', ' ').toUpperCase(),
        'order_id': order['order_id'],
        'prefill': {
          'name':    (order['prefill'] as Map?)?['name']    ?? '',
          'email':   (order['prefill'] as Map?)?['email']   ?? '',
          'contact': (order['prefill'] as Map?)?['contact'] ?? '',
        },
        'theme': {'color': '#EC4899'},
      });
    } catch (e) {
      setState(() { _purchasing = false; });
      if (mounted) _snack(e.toString(), error: true);
    }
  }

  void _onSuccess(PaymentSuccessResponse r) async {
    final order = _pendingOrder;
    if (order == null) { setState(() => _purchasing = false); return; }
    try {
      await ApiService.verifySubscriptionPayment(
        orderId:   order['order_id'] as String,
        paymentId: r.paymentId ?? '',
        signature: r.signature ?? '',
        plan:      _selectedSlug!,
      );
      await context.read<AuthProvider>().refreshProfile();
      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) _snack('Verification failed: $e', error: true);
    } finally {
      if (mounted) setState(() { _purchasing = false; _pendingOrder = null; });
    }
  }

  void _onError(PaymentFailureResponse r) {
    setState(() { _purchasing = false; _pendingOrder = null; });
    if (mounted && r.code != 2) _snack(r.message ?? 'Payment failed', error: true);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: const Color(0xFFEC4899).withOpacity(0.35),
                      blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text("You're Premium! 🎉",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Color(0xFF111827))),
              const SizedBox(height: 8),
              const Text('Your subscription is now active.\nEnjoy all premium features!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Start Exploring',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFEC4899))),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
            leading: BackButton(color: const Color(0xFF374151))),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            const SizedBox(height: 20),
            TextButton(onPressed: _load,
                child: const Text('Retry',
                    style: TextStyle(color: Color(0xFFEC4899)))),
          ]),
        ),
      );
    }

    final isPro = _selectedTier == 'pro';
    final alreadyOnTier = _currentTier == _selectedTier;
    final tierPlans = _tierPlans(_selectedTier);
    final features = isPro ? _proFeatures : _plusFeatures;
    final basePrice = tierPlans
        .firstWhere((p) => p['months'] == 1, orElse: () => {'monthly_inr': 0})['monthly_inr'] as num;

    final headerGrad = isPro
        ? const LinearGradient(
            colors: [Color(0xFF78350F), Color(0xFFB45309)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(
            colors: [Color(0xFF831843), Color(0xFFDB2777)],
            begin: Alignment.topLeft, end: Alignment.bottomRight);
    final accentColor = isPro ? const Color(0xFFD97706) : const Color(0xFFEC4899);
    final accentBg = isPro ? const Color(0xFFFFFBEB) : const Color(0xFFFDF2F8);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor:
                    isPro ? const Color(0xFF92400E) : const Color(0xFF9D174D),
                surfaceTintColor: Colors.transparent,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 16),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(gradient: headerGrad),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.workspace_premium_rounded,
                                color: Colors.white, size: 30),
                          ),
                          const SizedBox(height: 12),
                          const Text('MatchInMinutes Premium',
                              style: TextStyle(color: Colors.white, fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            isPro
                                ? 'Voice & video calls + everything in Plus'
                                : 'Get noticed sooner and go on 3X more dates',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tier toggle ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            _TierTab(label: 'Plus', active: !isPro,
                                color: const Color(0xFFEC4899),
                                onTap: () => _switchTier('plus')),
                            _TierTab(label: 'Pro', active: isPro,
                                color: const Color(0xFFD97706),
                                onTap: () => _switchTier('pro')),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Plan cards ───────────────────────────────────────
                      ...tierPlans.map((plan) {
                        final slug = plan['slug'] as String;
                        final months = plan['months'] as int;
                        final monthly = plan['monthly_inr'] as num;
                        final total = plan['total_inr'] as num;
                        final save = months > 1
                            ? (((basePrice - monthly) / basePrice) * 100).round()
                            : 0;
                        final isSelected = slug == _selectedSlug;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedSlug = slug),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? accentBg : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? accentColor : const Color(0xFFE5E7EB),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                // Radio dot
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? accentColor : Colors.transparent,
                                    border: Border.all(
                                        color: isSelected ? accentColor : const Color(0xFFD1D5DB),
                                        width: 2),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),

                                // Label + badges
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(
                                          months == 1 ? '1 Month'
                                              : months == 3 ? '3 Months'
                                              : '6 Months',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? accentColor
                                                : const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (months == 6)
                                          _Badge('Best value', accentColor)
                                        else if (save > 0)
                                          _Badge('Save $save%', accentColor),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(
                                        '₹${total.toStringAsFixed(0)} billed upfront',
                                        style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Price
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${monthly.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? accentColor
                                              : const Color(0xFF111827),
                                        )),
                                    const Text('/month',
                                        style: TextStyle(
                                            fontSize: 11, color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // ── Features ─────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPro ? "What's included in Pro" : "What's included in Plus",
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 14),
                            ...features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                      color: accentBg, shape: BoxShape.circle),
                                  child: Icon(f.$1, size: 16, color: accentColor),
                                ),
                                const SizedBox(width: 12),
                                Text(f.$2,
                                    style: const TextStyle(
                                        fontSize: 14, color: Color(0xFF374151))),
                              ]),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky subscribe bar ─────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12, offset: const Offset(0, -3))],
              ),
              child: alreadyOnTier
                  ? Container(
                      height: 52,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14)),
                      child: Center(
                        child: Text(
                          'You\'re on ${isPro ? "Pro" : "Plus"} ✓',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _purchasing ? null : _subscribe,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPro
                                ? [const Color(0xFFB45309), const Color(0xFFD97706)]
                                : [const Color(0xFFEC4899), const Color(0xFFDB2777)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                              color: accentColor.withOpacity(0.35),
                              blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Center(
                          child: _purchasing
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  'Subscribe to ${isPro ? "Pro" : "Plus"}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub widgets ──────────────────────────────────────────────────────────────

class _TierTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TierTab({required this.label, required this.active,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF6B7280))),
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: color)),
      );
}
