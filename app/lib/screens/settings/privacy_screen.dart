import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: ListView(
        children: [
          // GDPR / CCPA intro
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We are committed to protecting your privacy and '
                  'complying with GDPR and CCPA regulations.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const _SectionHeader(title: 'Data Collection'),
          SwitchListTile(
            title: const Text('Analytics'),
            subtitle: const Text(
              'Help improve the app by sharing anonymous usage data',
            ),
            value: settings.analyticsEnabled,
            onChanged: notifier.setAnalyticsEnabled,
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile(
            title: const Text('Crash Reporting'),
            subtitle: const Text(
              'Automatically send crash reports to help fix bugs',
            ),
            value: settings.crashReportingEnabled,
            onChanged: (v) => notifier.setAnalyticsEnabled(v),
          ),
          const _SectionHeader(title: 'CCPA Rights (California Residents)'),
          SwitchListTile(
            title: const Text('Do Not Sell My Personal Information'),
            subtitle: const Text(
              'Opt out of the sale of your personal data',
            ),
            value: settings.doNotSellData,
            onChanged: notifier.setDoNotSellData,
          ),
          const _SectionHeader(title: 'GDPR Rights'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export My Data'),
            subtitle: const Text('Download a copy of all your personal data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading:
                const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text(
              'Delete My Data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
              'Permanently delete all your data from our servers',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDeleteDataDialog(context),
          ),
          const _SectionHeader(title: 'Legal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.cookie_outlined),
            title: const Text('Cookie Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showDeleteDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will permanently delete all your personal data from our servers. '
          'This includes location history, activity data, and pet profiles. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              // Handle data deletion request
            },
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
