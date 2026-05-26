import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/time_utils.dart';

class GiftsInboxScreen extends StatefulWidget {
  const GiftsInboxScreen({super.key});

  @override
  State<GiftsInboxScreen> createState() => _GiftsInboxScreenState();
}

class _GiftsInboxScreenState extends State<GiftsInboxScreen> {
  List<Map<String, dynamic>> _gifts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getReceivedGifts();
      if (mounted) {
        setState(() {
          _gifts = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Received gifts',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _gifts.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: const Color(0xFFEC4899),
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _gifts.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 76, color: Color(0xFFF3F4F6)),
                        itemBuilder: (_, i) => _GiftTile(gift: _gifts[i]),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Icon(Icons.card_giftcard_rounded, size: 36, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 16),
            const Text('No gifts yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            const Text('Gifts you receive will appear here',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _GiftTile extends StatelessWidget {
  final Map<String, dynamic> gift;
  const _GiftTile({required this.gift});

  @override
  Widget build(BuildContext context) {
    // Backend returns nested objects:
    //   sender: profiles!sender_id  → { name, main_image_url }
    //   gift:   gifts!gift_id       → { slug, name, icon, tier }
    final senderMap  = gift['sender'] as Map?;
    final giftMap    = gift['gift']   as Map?;

    final senderName  = senderMap?['name']           as String? ?? 'Unknown';
    final senderPhoto = senderMap?['main_image_url'] as String?;

    final giftName    = giftMap?['name'] as String? ?? giftMap?['slug'] as String? ?? 'Gift';
    final giftEmoji   = giftMap?['icon'] as String? ?? '🎁';
    const String? giftImageUrl = null; // catalog uses emoji icons, not image URLs

    // receiver_share = 70 % of cost credited to recipient
    final creditsValue = gift['receiver_share'] as int? ?? gift['cost'] as int?;
    final ts      = gift['created_at'] as String?;
    final message = gift['message']    as String?;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender avatar
          ClipOval(
            child: senderPhoto != null
                ? CachedNetworkImage(
                    imageUrl: senderPhoto,
                    width: 48, height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _InitialAvatar(name: senderName),
                  )
                : _InitialAvatar(name: senderName),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        senderName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827)),
                      ),
                    ),
                    if (ts != null)
                      Text(
                        _formatTs(ts),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Gift image or emoji
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: giftImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: CachedNetworkImage(
                                imageUrl: giftImageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    Center(child: Text(giftEmoji, style: const TextStyle(fontSize: 22))),
                              ),
                            )
                          : Center(
                              child: Text(giftEmoji,
                                  style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(giftName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827))),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (creditsValue != null) ...[
                                const Icon(Icons.bolt_rounded,
                                    size: 13, color: Color(0xFF16A34A)),
                                Text('+$creditsValue credits',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                              ],
                              if ((giftMap?['tier'] as String?) != null)
                                _TierBadge(tier: giftMap!['tier'] as String),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      '"$message"',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(String iso) {
    try {
      return timeAgo(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final cfg = switch (tier.toLowerCase()) {
      'legendary' => (label: '✦ Legendary', bg: const Color(0xFFFFF7ED), fg: const Color(0xFFEA580C)),
      'epic'      => (label: '★ Epic',      bg: const Color(0xFFF5F3FF), fg: const Color(0xFF7C3AED)),
      'rare'      => (label: '◆ Rare',      bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
      _           => (label: '· Common',    bg: const Color(0xFFF0FDF4), fg: const Color(0xFF16A34A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(cfg.label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cfg.fg)),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 48, height: 48,
        color: const Color(0xFFFDE7F3),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEC4899)),
          ),
        ),
      );
}
