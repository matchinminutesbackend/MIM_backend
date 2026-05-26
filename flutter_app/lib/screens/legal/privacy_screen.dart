import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
        title: const Text('Privacy Policy',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _LegalContent(sections: _privacy),
      ),
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

const _privacy = [
  _Section('Last updated: May 2025', ''),
  _Section('1. Introduction',
      'Lazyrabbit Technologies ("we", "us", "our") operates MatchInMinutes. This Privacy Policy explains how we collect, use, disclose, and protect your personal information when you use our App. By using MatchInMinutes, you consent to the practices described in this policy.'),
  _Section('2. Information We Collect',
      'We collect the following types of information:\n\n'
      '• Personal details: name, date of birth, gender, city, country\n'
      '• Profile content: photos, bio, hobbies, relationship goals\n'
      '• Verification data: selfie photo for face verification (not stored after verification)\n'
      '• Communication data: messages sent between matched users\n'
      '• Usage data: how you interact with the App, swipe activity, login times\n'
      '• Device data: device type, OS version, app version, IP address'),
  _Section('3. How We Use Your Information',
      'We use your information to:\n\n'
      '• Create and manage your account\n'
      '• Show you potential matches based on your preferences\n'
      '• Enable messaging between matched users\n'
      '• Verify your identity and maintain platform safety\n'
      '• Process payments for subscriptions\n'
      '• Send you relevant notifications and updates\n'
      '• Improve the App through analytics\n'
      '• Comply with legal obligations'),
  _Section('4. Face Verification',
      'We use selfie photos solely to verify that your profile photos match a real person. Verification images are reviewed by our safety team and are not used for any other purpose. We do not use facial recognition technology to identify you across other platforms.'),
  _Section('5. Sharing Your Information',
      'We do not sell your personal data. We may share your information with:\n\n'
      '• Other users: your profile details are visible to potential matches\n'
      '• Service providers: payment processors, cloud storage, analytics partners — only as needed to operate the App\n'
      '• Legal authorities: if required by law, court order, or to protect safety\n\n'
      'All third-party providers are bound by confidentiality agreements.'),
  _Section('6. Data Retention',
      'We retain your personal data for as long as your account is active. When you delete your account, we delete your personal data within 30 days, except where we are required to retain it for legal or fraud-prevention purposes. Messages may be retained for a limited period for safety investigations.'),
  _Section('7. Your Rights',
      'You have the right to:\n\n'
      '• Access the personal data we hold about you\n'
      '• Correct inaccurate data\n'
      '• Request deletion of your account and data\n'
      '• Withdraw consent for data processing\n'
      '• Lodge a complaint with a data protection authority\n\n'
      'To exercise these rights, contact us at support@lazyrabbit.in.'),
  _Section('8. Data Security',
      'We use industry-standard security measures including encryption in transit (HTTPS/TLS), secure token authentication, and access controls to protect your data. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.'),
  _Section('9. Location Data',
      'We collect city and country information that you provide manually. We do not access your device\'s GPS or precise location without your explicit permission. Location data is used only to suggest relevant matches near you.'),
  _Section('10. Children\'s Privacy',
      'MatchInMinutes is strictly for users aged 18 and above. We do not knowingly collect personal data from anyone under 18. If we discover that a user is under 18, we will immediately terminate their account and delete their data.'),
  _Section('11. Cookies & Tracking',
      'Our App may use analytics tools that collect anonymised usage data to help us improve the App experience. This data does not identify you personally. You can opt out of analytics tracking in your device settings.'),
  _Section('12. Changes to This Policy',
      'We may update this Privacy Policy periodically. We will notify you of significant changes through the App or by email. Continued use of the App after changes constitutes your acceptance of the updated policy.'),
  _Section('13. Contact Us',
      'If you have any questions or concerns about this Privacy Policy, please reach out:\n\nsupport@lazyrabbit.in\nLazyrabbit Technologies\nIndia'),
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
