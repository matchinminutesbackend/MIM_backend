import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../services/api_service.dart';

class PartnerPreferencesScreen extends StatefulWidget {
  const PartnerPreferencesScreen({super.key});

  @override
  State<PartnerPreferencesScreen> createState() =>
      _PartnerPreferencesScreenState();
}

class _PartnerPreferencesScreenState
    extends State<PartnerPreferencesScreen> {
  RangeValues _ageRange = const RangeValues(18, 45);
  String? _relationshipGoal;
  String? _city;
  bool _saving = false;

  // (display label → backend enum value) — serious_marriage excluded
  static const _goals = [
    ('Long-term relationship', 'long_term'),
    ('Short-term dating',      'short_term'),
    ('Marriage',               'marriage'),
    ('Friendship first',       'friendship'),
    ('Just exploring',         'casual'),
    ('Not sure yet',           'unsure'),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updatePartnerPreferences({
        'min_age': _ageRange.start.round(),
        'max_age': _ageRange.end.round(),
        if (_relationshipGoal != null)
          'preferred_relationship_goal': _relationshipGoal,
        if (_city != null && _city!.trim().isNotEmpty) 'preferred_city': _city!.trim(),
      });

      if (!mounted) return;

      // Refresh cached preferences in AuthProvider
      await context.read<AuthProvider>().fetchPartnerPreferences();

      // Re-apply to Discover immediately — user sees filtered results
      // when they switch back to the Discover tab.
      context.read<DiscoverProvider>().applyFilters(_buildFilters());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved — Discover updated ✓'),
            backgroundColor: Color(0xFFEC4899),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Converts current screen state → discover filter map.
  Map<String, String> _buildFilters() {
    final m = <String, String>{};
    m['min_age'] = '${_ageRange.start.round()}';
    m['max_age'] = '${_ageRange.end.round()}';
    if (_relationshipGoal != null) m['relationship_goal'] = _relationshipGoal!;
    if (_city != null && _city!.isNotEmpty) m['city'] = _city!;
    return m;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.partnerPreferences == null) {
        await auth.fetchPartnerPreferences();
      }
      _loadExisting();
    });
  }

  void _loadExisting() {
    final prefs = context.read<AuthProvider>().partnerPreferences;
    if (prefs == null) return;
    setState(() {
      _ageRange = RangeValues(
        (prefs['min_age'] as num?)?.toDouble() ?? 18,
        (prefs['max_age'] as num?)?.toDouble() ?? 45,
      );
      _relationshipGoal = prefs['preferred_relationship_goal'] as String?;
      _city = prefs['preferred_city'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Partner Preferences',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Age range
          _SectionCard(
            title: 'Age Range',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_ageRange.start.round()} yrs',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEC4899))),
                    Text('${_ageRange.end.round()} yrs',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEC4899))),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFEC4899),
                    inactiveTrackColor: const Color(0xFFFBCFE8),
                    thumbColor: const Color(0xFFEC4899),
                    overlayColor: const Color(0xFFEC4899).withOpacity(0.15),
                    rangeThumbShape:
                        const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 70,
                    divisions: 52,
                    onChanged: (v) => setState(() => _ageRange = v),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Looking for (relationship goal)
          _SectionCard(
            title: 'Looking for',
            child: _ChipGroup(
              options: _goals.map((g) => g.$1).toList(),
              selected: _goals
                  .where((g) => g.$2 == _relationshipGoal)
                  .map((g) => g.$1)
                  .firstOrNull,
              onSelect: (label) {
                final goal = _goals.firstWhere((g) => g.$1 == label,
                    orElse: () => ('', ''));
                final backendValue = goal.$2.isEmpty ? null : goal.$2;
                setState(() => _relationshipGoal =
                    _relationshipGoal == backendValue ? null : backendValue);
              },
            ),
          ),

          const SizedBox(height: 12),

          // City
          _SectionCard(
            title: 'City',
            child: _TextField(
              label: 'City (optional)',
              value: _city,
              onChanged: (v) => setState(() => _city = v.isEmpty ? null : v),
            ),
          ),

          const SizedBox(height: 24),

          // Save button
          GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFEC4899).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Save Preferences',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub widgets ──

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
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
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final void Function(String) onSelect;
  const _ChipGroup(
      {required this.options,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final active = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFDF2F8)
                    : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active
                        ? const Color(0xFFEC4899)
                        : const Color(0xFFE5E7EB),
                    width: active ? 1.5 : 1),
              ),
              child: Text(opt,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: active
                          ? const Color(0xFFEC4899)
                          : const Color(0xFF374151))),
            ),
          );
        }).toList(),
      );
}

class _TextField extends StatelessWidget {
  final String label;
  final String? value;
  final void Function(String) onChanged;
  const _TextField(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: label,
          hintStyle:
              const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFFEC4899), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
        ),
      );
}
