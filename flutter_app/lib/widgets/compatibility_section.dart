import 'package:flutter/material.dart';

import '../utils/compatibility_questions.dart';

/// Horizontal scrollable Q&A cards shown on profile views.
/// [answers] is the list stored in profile: [{question: ..., answer: ...}]
/// [title] is the section heading (e.g. "Long term compatibility")
class CompatibilitySection extends StatelessWidget {
  final List<Map<String, dynamic>> answers;
  final String title;

  const CompatibilitySection({
    super.key,
    required this.answers,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: answers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final q = answers[i]['question'] as String? ?? '';
              final a = answers[i]['answer'] as String? ?? '';
              return _QACard(question: q, answer: a);
            },
          ),
        ),
      ],
    );
  }
}

class _QACard extends StatelessWidget {
  final String question;
  final String answer;
  const _QACard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(answer,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

/// Edit section shown in EditProfileScreen.
/// Shows cards if answered, or an "Add" prompt if empty.
class CompatibilityEditSection extends StatelessWidget {
  final List<Map<String, dynamic>> answers;
  final String title;
  final VoidCallback onEdit;

  const CompatibilityEditSection({
    super.key,
    required this.answers,
    required this.title,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
                const Spacer(),
                GestureDetector(
                  onTap: onEdit,
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 14, color: Color(0xFFEC4899)),
                      SizedBox(width: 4),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFEC4899),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cards or empty state
          if (answers.isEmpty)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFBCFE8),
                      style: BorderStyle.solid),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: Color(0xFFEC4899), size: 28),
                      SizedBox(height: 6),
                      Text('Answer compatibility questions',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFEC4899),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                itemCount: answers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final q = answers[i]['question'] as String? ?? '';
                  final a = answers[i]['answer'] as String? ?? '';
                  return _QACard(question: q, answer: a);
                },
              ),
            ),
        ],
      ),
    );
  }
}
