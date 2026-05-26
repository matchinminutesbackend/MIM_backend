import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
        title: const Text('Terms & Conditions',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _LegalContent(sections: _terms),
      ),
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

const _terms = [
  _Section('Last updated: May 2025', ''),
  _Section('1. Acceptance of Terms',
      'By downloading or using MatchInMinutes ("the App"), you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the App. These terms constitute a legally binding agreement between you and Lazyrabbit Technologies ("we", "us", "our").'),
  _Section('2. Eligibility',
      'You must be at least 18 years old to use MatchInMinutes. By using the App, you confirm that you are 18 years of age or older and have the legal capacity to enter into these terms. We reserve the right to suspend or terminate accounts of users found to be underage.'),
  _Section('3. Account Registration',
      'You are responsible for maintaining the confidentiality of your account credentials. You agree to provide accurate, current, and complete information during registration and to update such information to keep it accurate. You are responsible for all activities that occur under your account.'),
  _Section('4. Acceptable Use',
      'You agree not to:\n\n• Harass, abuse, threaten, or intimidate other users\n• Post false, misleading, or deceptive content\n• Share explicit, offensive, or inappropriate content\n• Impersonate another person or create fake profiles\n• Use the App for any commercial or promotional purposes without consent\n• Attempt to hack, scrape, or reverse-engineer the App\n• Engage in any activity that violates applicable laws'),
  _Section('5. Profile & Content',
      'You are solely responsible for the content you post on your profile, including photos, bio, and any messages you send. We reserve the right to remove content that violates these terms without notice. By posting content, you grant us a non-exclusive, royalty-free license to use, display, and distribute it within the App.'),
  _Section('6. Safety',
      'MatchInMinutes uses face verification to help maintain a safe community, but we cannot guarantee the identity or intentions of every user. We strongly encourage you to:\n\n• Meet in public places for first meetings\n• Inform a friend or family member of your plans\n• Trust your instincts — report suspicious behaviour immediately\n• Never share financial information with matches'),
  _Section('7. Subscriptions & Payments',
      'Some features require a paid subscription. All payments are processed securely. Subscriptions automatically renew unless cancelled at least 24 hours before the renewal date. Refunds are issued at our sole discretion and in accordance with applicable consumer protection laws.'),
  _Section('8. Termination',
      'We reserve the right to suspend or terminate your account at any time for violation of these terms, inappropriate behaviour, or any reason we deem necessary to maintain a safe community. You may also delete your account at any time from your profile settings.'),
  _Section('9. Disclaimer of Warranties',
      'The App is provided "as is" without any warranties, express or implied. We do not guarantee that you will find a match, that the App will be error-free, or that connections made through the App will be successful.'),
  _Section('10. Limitation of Liability',
      'To the maximum extent permitted by law, Lazyrabbit Technologies shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App, including but not limited to damages for loss of data, loss of goodwill, or personal injury.'),
  _Section('11. Governing Law',
      'These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising from these terms shall be subject to the exclusive jurisdiction of the courts in India.'),
  _Section('12. Changes to Terms',
      'We may update these Terms from time to time. We will notify you of significant changes through the App or by email. Continued use of the App after changes constitutes acceptance of the revised Terms.'),
  _Section('13. Contact Us',
      'If you have questions about these Terms, please contact us at:\n\nsupport@lazyrabbit.in\nLazyrabbit Technologies\nIndia'),
];

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

class _LegalContent extends StatelessWidget {
  final List<_Section> sections;
  const _LegalContent({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in sections) ...[
          if (s.title.isNotEmpty)
            Text(s.title,
                style: TextStyle(
                  fontSize: s.title.startsWith('Last') ? 12 : 15,
                  fontWeight: s.title.startsWith('Last') ? FontWeight.normal : FontWeight.bold,
                  color: s.title.startsWith('Last') ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                )),
          if (s.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.body,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF4B5563), height: 1.6)),
          ],
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
