import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _selectedCategory;
  final _descController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  static const _categories = [
    'Account issue',
    'Billing / subscription',
    'Technical problem',
    'Safety concern',
    'Profile or match issue',
    'Other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedCategory == null || _descController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiService.submitReport(
        reportedId: '',   // empty = general complaint
        reason: _selectedCategory!,
        description: _descController.text.trim(),
      );
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: const Text('Help & Support',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Complaint Submitted!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text(
            'Our support team will review your complaint and get back to you within 24 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildForm() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF2F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFBCFE8)),
          ),
          child: const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: Color(0xFFEC4899), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('We\'re here to help', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    SizedBox(height: 2),
                    Text('support@lazyrabbit.in', style: TextStyle(
                        fontSize: 12, color: Color(0xFFEC4899))),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text('Category', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((c) {
            final active = _selectedCategory == c;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFDF2F8) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? const Color(0xFFEC4899) : const Color(0xFFE5E7EB),
                      width: active ? 1.5 : 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                      blurRadius: 4, offset: const Offset(0, 1))],
                ),
                child: Text(c, style: TextStyle(
                    fontSize: 13,
                    color: active ? const Color(0xFFEC4899) : const Color(0xFF374151),
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        const Text('Describe your issue', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 10),
        TextField(
          controller: _descController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Please describe the issue in detail...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEC4899))),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFFBCFE8),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _submitting || _selectedCategory == null ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Submit Complaint',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    ),
  );
}
