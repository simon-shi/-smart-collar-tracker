import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.account),
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(v);
                }
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.straighten_outlined),
            title: const Text('Units'),
            trailing: DropdownButton<String>(
              value: settings.units,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'metric', child: Text('Metric')),
                DropdownMenuItem(value: 'imperial', child: Text('Imperial')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setUnits(v);
                }
              },
            ),
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.notificationSettings),
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'Privacy & Legal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.privacy),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export My Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.dataExport),
          ),
          const Divider(height: 1),
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            trailing: const Text('1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {},
          ),
          const Divider(height: 1),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go(Routes.login);
              },
              child: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 24),
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
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
