import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Privacy Policy'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'StudySwap Privacy Policy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Effective Date: October 2025',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[500] : Colors.black54,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "StudySwap ('we', 'us', or 'our') is committed to protecting your privacy. This Privacy Policy describes how we collect, use, disclose, and protect your information when you use the StudySwap mobile application and related services.",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "1. Information We Collect",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              "- Personal Data: Your name, email, phone number, photo, location, and institution may be collected during registration or app use.\n"
              "- Transaction Data: Details of marketplace activity (items, transactions, chat, history, ratings) are stored to enable app features.\n"
              "- Device Information: Non-personal data like device type and app usage helps us improve performance and user experience.\n"
              "- Authentication: Login info may be handled by third-party providers (e.g., Firebase).",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "2. How We Use Data",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '''- To operate StudySwap features (marketplace, notifications, profile, chat, transaction history).
- To maintain secure authentication and account management.
- For analytics, improvement, safety, and support purposes.
- We do not sell or share your personal data beyond what is required for core app operations.''',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "3. User Controls",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '''
- You can delete your account if no pending transactions.''',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "4. Security",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '''- We implement safeguards and encryption to protect your info.''',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "5. Children's Privacy",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '''- StudySwap does not knowingly collect data from users under 13. Contact support if this occurs in error.''',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "6. Policy Updates",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '''- We'll notify users of changes via the app or other platform.''',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              "Contact Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '''- For inquiries, email us at: Mosang@gmail.com''',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
