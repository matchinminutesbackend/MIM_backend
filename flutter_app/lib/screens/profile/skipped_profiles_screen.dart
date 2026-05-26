import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/match_model.dart';
import '../../services/api_service.dart';
import '../profile/profile_detail_screen.dart';

class SkippedProfilesScreen extends StatefulWidget {
  const SkippedProfilesScreen({super.key});

  @override
  State<SkippedProfilesScreen> createState() => _SkippedProfilesScreenState();
}

class _SkippedProfilesScreenState extends State<SkippedProfilesScreen> {
  List<MatchModel> _list = [];
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
      final data = await ApiService.getDislikedByMe();
      if (mounted) {
        setState(() {
          _list = (data as List)
              .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
              .toList();
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
        title: const Text('Skipped profiles',
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
                      Text(_error!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _list.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: const Color(0xFFEC4899),
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => _SkippedCard(
                          match: _list[i],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileDetailScreen(userId: _list[i].partnerId),
                              ),
                            );
                          },
                        ),
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
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.history_rounded, size: 36, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            const Text('No skipped profiles',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 6),
            const Text('Profiles you pass on will appear here',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );
}

class _SkippedCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  const _SkippedCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF3F4F6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            match.partnerPhotoUrl != null
                ? CachedNetworkImage(
                    imageUrl: match.partnerPhotoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _Placeholder(name: match.partnerName),
                  )
                : _Placeholder(name: match.partnerName),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Name at bottom
            Positioned(
              left: 10, right: 10, bottom: 10,
              child: Text(
                match.partnerName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF3F4F6),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)),
          ),
        ),
      );
}
