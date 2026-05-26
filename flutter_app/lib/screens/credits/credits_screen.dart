import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../gifts/gifts_inbox_screen.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final Razorpay _razorpay;

  bool _loadingBalance = true;
  bool _loadingPacks = true;
  bool _purchasing = false;

  int _balance = 0;
  int _lifetimeEarned = 0;
  int _lifetimeSpent = 0;
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _transactions = [];
  int _selectedCredits = 0;
  String? _razorpayKey;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    } catch (_) {
      // Plugin not available (web/desktop preview) — mock mode will handle payment
    }
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    try { _razorpay.clear(); } catch (_) {}
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadBalance(), _loadPacks(), _loadConfig()]);
    _loadTransactions();
  }

  Future<void> _loadBalance() async {
    try {
      final data = await ApiService.getWalletBalance();
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;
        _lifetimeEarned = (data['lifetime_earned'] as num?)?.toInt() ?? 0;
        _lifetimeSpent = (data['lifetime_spent'] as num?)?.toInt() ?? 0;
        _loadingBalance = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _loadPacks() async {
    try {
      final data = await ApiService.getWalletPacks();
      if (!mounted) return;
      final packs = data.map((p) => Map<String, dynamic>.from(p as Map)).toList();
      setState(() {
        _packs = packs;
        if (packs.isNotEmpty) {
          // Default select the 3rd pack (200 credits, best value)
          _selectedCredits = (packs.length > 2
                  ? packs[2]
                  : packs.last)['credits'] as int;
        }
        _loadingPacks = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPacks = false);
    }
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiService.getWalletConfig();
      if (!mounted) return;
      _razorpayKey = data['key_id'] as String?;
    } catch (_) {}
  }

  Future<void> _loadTransactions() async {
    try {
      final data = await ApiService.getWalletTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = data
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _buy() async {
    if (_selectedCredits == 0 || _purchasing) return;
    final pack = _packs.firstWhere(
      (p) => p['credits'] == _selectedCredits,
      orElse: () => {},
    );
    if (pack.isEmpty) return;

    setState(() => _purchasing = true);
    try {
      // Gate: ensure billing details are filled before payment
      final billing = await ApiService.getBillingDetails();
      final billingName = billing['name'] as String? ?? '';
      if (billingName.isEmpty) {
        setState(() => _purchasing = false);
        _snack('Please fill in your billing details first.', error: false);
        _showBillingSheet();
        return;
      }

      final order = await ApiService.createWalletOrder(_selectedCredits);
      final keyId = _razorpayKey ?? order['key_id'] ?? '';
      final isMock = keyId == 'mock' || keyId.isEmpty;

      if (isMock) {
        // Dev/test mode: skip Razorpay, auto-verify
        await ApiService.verifyWalletPayment(
          orderId: order['order_id'] ?? '',
          paymentId: 'mock_pay_${DateTime.now().millisecondsSinceEpoch}',
          signature: 'mock_sig',
          credits: _selectedCredits,
        );
        await _onPurchaseComplete(_selectedCredits);
        return;
      }

      final amountPaise = (pack['inr_paise'] as num).toInt();
      final auth = context.read<AuthProvider>();
      try {
        _razorpay.open({
          'key': keyId,
          'order_id': order['order_id'],
          'amount': amountPaise,
          'name': 'MatchInMinutes',
          'description': '$_selectedCredits Credits',
          'prefill': {
            'email': auth.user?.email ?? '',
          },
          'theme': {'color': '#EC4899'},
        });
      } catch (_) {
        // Razorpay plugin unavailable on this platform
        if (mounted) _snack('Payment not available on this device/platform.', error: true);
        setState(() => _purchasing = false);
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
      setState(() => _purchasing = false);
    } catch (_) {
      if (mounted) _snack('Payment failed. Try again.', error: true);
      setState(() => _purchasing = false);
    }
  }

  void _onPaySuccess(PaymentSuccessResponse res) async {
    try {
      await ApiService.verifyWalletPayment(
        orderId: res.orderId ?? '',
        paymentId: res.paymentId ?? '',
        signature: res.signature ?? '',
        credits: _selectedCredits,
      );
      await _onPurchaseComplete(_selectedCredits);
    } catch (e) {
      if (mounted) _snack('Verification failed: $e', error: true);
      setState(() => _purchasing = false);
    }
  }

  void _onPayError(PaymentFailureResponse res) {
    if (mounted) {
      _snack('Payment cancelled', error: false);
      setState(() => _purchasing = false);
    }
  }

  Future<void> _onPurchaseComplete(int credits) async {
    await context.read<AuthProvider>().refreshProfile();
    await _loadBalance();
    await _loadTransactions();
    if (mounted) {
      setState(() => _purchasing = false);
      _showSuccessDialog(credits);
    }
  }

  void _showSuccessDialog(int credits) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Credits Added!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('$credits credits have been\nadded to your wallet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Awesome!',
                    style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFFF3F4F6),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            titleSpacing: 20,
            title: const Text('Credits',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFFEC4899),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFFEC4899),
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Buy Credits'), Tab(text: 'History')],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildBuyTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 12),
          _buildGiftsLink(),
          const SizedBox(height: 12),
          _buildHowItWorks(),
          const SizedBox(height: 20),
          _buildPacksSection(),
          const SizedBox(height: 24),
          _buildBuyButton(),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _loadingBalance
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Balance',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('⚡',
                              style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 6),
                          Text('$_balance',
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(width: 4),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text('credits',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatPill(
                        label: 'Earned',
                        value: '+$_lifetimeEarned',
                        color: Colors.white24),
                    const SizedBox(height: 6),
                    _StatPill(
                        label: 'Spent',
                        value: '-$_lifetimeSpent',
                        color: Colors.white24),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildGiftsLink() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GiftsInboxScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: Color(0xFF16A34A), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Received gifts',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827))),
                  Text('See all gifts you have received',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What can I do with credits?',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          _UsageRow(emoji: '❤️', label: 'Send hearts to profiles you like'),
          _UsageRow(emoji: '🎁', label: 'Send gifts in chat to stand out'),
          _UsageRow(emoji: '⚡', label: 'Boost your profile visibility'),
          _UsageRow(emoji: '💬', label: 'Message matches before they respond'),
        ],
      ),
    );
  }

  Widget _buildPacksSection() {
    if (_loadingPacks) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFEC4899)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose a Pack',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
        const SizedBox(height: 12),
        ..._packs.map((pack) {
          final credits = pack['credits'] as int;
          final paise = (pack['inr_paise'] as num).toInt();
          final inr = paise ~/ 100;
          final discountPct = (pack['discount_pct'] as num).toInt();
          final originalInr = credits; // 1 credit = ₹1 base
          final selected = _selectedCredits == credits;
          final isBest = discountPct >= 20;

          return GestureDetector(
            onTap: () => setState(() => _selectedCredits = credits),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFDF2F8) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFEC4899)
                      : const Color(0xFFE5E7EB),
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEC4899)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _packEmoji(credits),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('$credits credits',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? const Color(0xFFEC4899)
                                      : const Color(0xFF111827))),
                          const SizedBox(width: 8),
                          if (isBest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEC4899),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Best value',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            )
                          else if (discountPct > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF9C3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Save $discountPct%',
                                  style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ]),
                        const SizedBox(height: 2),
                        if (discountPct > 0)
                          Text('₹$originalInr → ₹$inr',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF)))
                        else
                          Text('₹$inr',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹$inr',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? const Color(0xFFEC4899)
                                  : const Color(0xFF111827))),
                      if (selected)
                        const Icon(Icons.check_circle,
                            color: Color(0xFFEC4899), size: 18),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _packEmoji(int credits) {
    if (credits >= 1000) return '💎';
    if (credits >= 500) return '🔥';
    if (credits >= 200) return '⚡';
    if (credits >= 100) return '✨';
    return '💫';
  }

  Widget _buildBuyButton() {
    final pack = _packs.firstWhere(
      (p) => p['credits'] == _selectedCredits,
      orElse: () => {},
    );
    final inr = pack.isNotEmpty
        ? (pack['inr_paise'] as num).toInt() ~/ 100
        : 0;

    return GestureDetector(
      onTap: _purchasing ? null : _buy,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFEC4899).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Center(
          child: _purchasing
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(
                  _selectedCredits > 0
                      ? 'Buy $_selectedCredits credits · ₹$inr'
                      : 'Select a pack',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Manage section
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              _ManageTile(
                icon: Icons.account_balance_outlined,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFEFF6FF),
                label: 'Billing details',
                subtitle: 'GST & billing info',
                onTap: () => _showBillingSheet(),
              ),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              _ManageTile(
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF16A34A),
                iconBg: const Color(0xFFF0FDF4),
                label: 'Payout details',
                subtitle: 'Bank / UPI for withdrawal',
                onTap: () => _showPayoutSheet(),
              ),
              const Divider(height: 16, color: Color(0xFFF3F4F6)),
              _ManageTile(
                icon: Icons.redeem_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFFFBEB),
                label: 'Request withdrawal',
                subtitle: 'Convert credits to cash',
                onTap: () => _showWithdrawalSheet(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                    child: const Center(
                        child: Text('⚡', style: TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(height: 16),
                  const Text('No transactions yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  const Text('Your credit history will appear here',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
        final tx = _transactions[i];
        final delta = (tx['delta'] as num?)?.toInt() ?? 0;
        final isCredit = delta > 0;
        final reason = tx['reason'] as String? ?? 'transaction';
        final ts = tx['created_at'] as String?;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isCredit
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  color: isCredit
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_txLabel(reason),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827))),
                  if (ts != null)
                    Text(_formatDate(ts),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : ''}$delta',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCredit
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626)),
            ),
          ]),
        );
              },
            ),
          ),
        ],
    );
  }

  void _showBillingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BillingDetailsSheet(),
    );
  }

  void _showPayoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PayoutDetailsSheet(),
    );
  }

  void _showWithdrawalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _WithdrawalSheet(balance: _balance, onSuccess: () {
        _loadBalance();
        _loadTransactions();
      }),
    );
  }

  String _txLabel(String reason) {
    const labels = {
      'purchase': 'Credits purchased',
      'gift_sent': 'Gift sent',
      'gift_received': 'Gift received',
      'signup_bonus': 'Welcome bonus',
      'heart_sent': 'Heart sent',
      'boost': 'Profile boosted',
      'withdrawal': 'Withdrawn',
      'withdrawal_refund': 'Withdrawal refunded',
      'admin_adjust': 'Admin adjustment',
    };
    return labels[reason] ?? reason.replaceAll('_', ' ');
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 10)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}

class _UsageRow extends StatelessWidget {
  final String emoji;
  final String label;
  const _UsageRow({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151))),
        ]),
      );
}

class _ManageTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _ManageTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
        ]),
      );
}

// ─── Billing details sheet ────────────────────────────────────────────────────

class _BillingDetailsSheet extends StatefulWidget {
  @override
  State<_BillingDetailsSheet> createState() => _BillingDetailsSheetState();
}

class _BillingDetailsSheetState extends State<_BillingDetailsSheet> {
  final _nameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getBillingDetails();
      _nameCtrl.text = data['name'] as String? ?? '';
      _gstCtrl.text = data['gst_number'] as String? ?? '';
      _addressCtrl.text = data['address'] as String? ?? '';
      _cityCtrl.text = data['city'] as String? ?? '';
      _pincodeCtrl.text = data['pincode'] as String? ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateBillingDetails({
        'name': _nameCtrl.text.trim(),
        'gst_number': _gstCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 20),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFEC4899))))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Billing details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 16),
                  _field(_nameCtrl, 'Full name / Company name'),
                  const SizedBox(height: 10),
                  _field(_gstCtrl, 'GST number (optional)'),
                  const SizedBox(height: 10),
                  _field(_addressCtrl, 'Address'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_cityCtrl, 'City')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_pincodeCtrl, 'Pincode',
                        keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 20),
                  _GradientBtn(
                      label: 'Save',
                      loading: _saving,
                      onTap: _saving ? null : _save),
                ],
              ),
      );

  Widget _field(TextEditingController ctrl, String label,
          {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2)),
        ),
      );
}

// ─── Payout details sheet ─────────────────────────────────────────────────────

class _PayoutDetailsSheet extends StatefulWidget {
  @override
  State<_PayoutDetailsSheet> createState() => _PayoutDetailsSheetState();
}

class _PayoutDetailsSheetState extends State<_PayoutDetailsSheet> {
  final _nameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getPayoutDetails();
      _nameCtrl.text = data['account_holder_name'] as String? ?? '';
      _accountCtrl.text = data['account_number'] as String? ?? '';
      _ifscCtrl.text = data['ifsc_code'] as String? ?? '';
      _upiCtrl.text = data['upi_id'] as String? ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updatePayoutDetails({
        'account_holder_name': _nameCtrl.text.trim(),
        'account_number': _accountCtrl.text.trim(),
        'ifsc_code': _ifscCtrl.text.trim().toUpperCase(),
        'upi_id': _upiCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 20),
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFEC4899))))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Payout details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  const Text('Add your bank or UPI details for withdrawals',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  const SizedBox(height: 16),
                  _field(_nameCtrl, 'Account holder name'),
                  const SizedBox(height: 10),
                  _field(_accountCtrl, 'Bank account number',
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _field(_ifscCtrl, 'IFSC code'),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  ]),
                  const SizedBox(height: 10),
                  _field(_upiCtrl, 'UPI ID'),
                  const SizedBox(height: 20),
                  _GradientBtn(
                      label: 'Save',
                      loading: _saving,
                      onTap: _saving ? null : _save),
                ],
              ),
      );

  Widget _field(TextEditingController ctrl, String label,
          {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2)),
        ),
      );
}

// ─── Withdrawal sheet ─────────────────────────────────────────────────────────

class _WithdrawalSheet extends StatefulWidget {
  final int balance;
  final VoidCallback onSuccess;
  const _WithdrawalSheet({required this.balance, required this.onSuccess});

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final credits = int.tryParse(_ctrl.text.trim()) ?? 0;
    if (credits <= 0 || credits > widget.balance) return;
    setState(() => _submitting = true);
    try {
      await ApiService.requestWithdrawal(credits);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Withdrawal request submitted! 💰'),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Request withdrawal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(children: [
                const Text('⚡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('Available: ${widget.balance} credits',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Credits to withdraw',
                labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFEC4899), width: 2)),
                helperText: 'Make sure payout details are saved before requesting',
                helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
            const SizedBox(height: 20),
            _GradientBtn(
                label: 'Request withdrawal',
                loading: _submitting,
                onTap: _submitting ? null : _submit),
          ],
        ),
      );
}

// ─── Shared gradient button ───────────────────────────────────────────────────

class _GradientBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _GradientBtn(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onTap == null
                  ? [const Color(0xFFD1D5DB), const Color(0xFF9CA3AF)]
                  : [const Color(0xFFEC4899), const Color(0xFFDB2777)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
          ),
        ),
      );
}
