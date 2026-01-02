import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final String policyUrl =
      'https://sites.google.com/view/confessme-privacy/home';

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(policyUrl);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.security, color: AppTheme.accentColor, size: 48),
            const SizedBox(height: 24),
            Text(
              'Your Privacy Matters',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ConfessMe is built on the principle of anonymity. We do not collect your name, email, or any identifying information. Your secrets are yours alone.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Data Collection',
              'We only collect anonymous data such as:',
              [
                'Anonymous Auth ID (Firebase)',
                'Device approximate location (optional, for local feeds)',
                'Content you voluntarily post',
              ],
            ),
            const SizedBox(height: 24),
            _buildSection('Data Usage', 'Your data is used to:', [
              'Display your confessions in the feed',
              'Prevent spam and abuse',
              'Improve app experience',
            ]),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: _launchUrl,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Read Full Policy Online'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'ConfessMe Team · 2026',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              children: [
                const Text('• ', style: TextStyle(color: AppTheme.accentColor)),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
