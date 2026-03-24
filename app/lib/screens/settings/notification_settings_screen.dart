import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('All Notifications'),
            subtitle: const Text('Master switch for all notifications'),
            value: settings.notificationsEnabled,
            onChanged: notifier.setNotificationsEnabled,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Geofence Alerts'),
            subtitle: const Text('When your pet enters or leaves a safe zone'),
            value: settings.geofenceAlertsEnabled &&
                settings.notificationsEnabled,
            onChanged: settings.notificationsEnabled
                ? notifier.setGeofenceAlerts
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Health Alerts'),
            subtitle: const Text('When unusual activity is detected'),
            value: settings.healthAlertsEnabled && settings.notificationsEnabled,
            onChanged: settings.notificationsEnabled
                ? notifier.setHealthAlerts
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Battery Alerts'),
            subtitle: const Text('When collar battery is low'),
            value: settings.batteryAlertsEnabled &&
                settings.notificationsEnabled,
            onChanged: settings.notificationsEnabled
                ? notifier.setBatteryAlerts
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Activity Goal'),
            subtitle: const Text('When your pet reaches daily activity goals'),
            value: settings.activityGoalEnabled && settings.notificationsEnabled,
            onChanged: settings.notificationsEnabled
                ? notifier.setActivityGoal
                : null,
          ),
        ],
      ),
    );
  }
}
