import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/device_provider.dart';
import '../../models/device.dart';
import '../../config/ble_config.dart';

class DeviceSettingsScreen extends ConsumerWidget {
  const DeviceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).valueOrNull;

    if (device == null) {
      return const Scaffold(
        body: Center(child: Text('No device connected')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Device Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Power Mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Power Mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...PowerMode.values.map(
                    (mode) => RadioListTile<PowerMode>(
                      title: Text(_powerModeLabel(mode)),
                      subtitle: Text(_powerModeDescription(mode)),
                      value: mode,
                      groupValue: device.powerMode,
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(deviceProvider.notifier).setGpsInterval(
                                _powerModeToGpsInterval(v),
                              );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // GPS Interval
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPS Update Interval',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: device.gpsIntervalSeconds,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 seconds (High Accuracy)')),
                      DropdownMenuItem(value: 30, child: Text('30 seconds (Normal)')),
                      DropdownMenuItem(value: 120, child: Text('2 minutes (Power Saving)')),
                      DropdownMenuItem(value: 600, child: Text('10 minutes (Ultra Low Power)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(deviceProvider.notifier).setGpsInterval(v);
                      }
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.gps_fixed),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // LED Settings
          Card(
            child: SwitchListTile(
              title: const Text('LED Light'),
              subtitle: const Text('Enable collar LED for night visibility'),
              value: device.ledEnabled,
              onChanged: (v) =>
                  ref.read(deviceProvider.notifier).sendLedCommand(v),
            ),
          ),
        ],
      ),
    );
  }

  String _powerModeLabel(PowerMode mode) {
    switch (mode) {
      case PowerMode.normal:
        return 'Normal';
      case PowerMode.lowPower:
        return 'Low Power';
      case PowerMode.ultraLowPower:
        return 'Ultra Low Power';
      case PowerMode.tracking:
        return 'Active Tracking';
    }
  }

  String _powerModeDescription(PowerMode mode) {
    switch (mode) {
      case PowerMode.normal:
        return 'Balanced performance and battery life';
      case PowerMode.lowPower:
        return 'Extended battery, less frequent updates';
      case PowerMode.ultraLowPower:
        return 'Maximum battery life, minimal updates';
      case PowerMode.tracking:
        return 'Maximum accuracy, higher battery usage';
    }
  }

  int _powerModeToGpsInterval(PowerMode mode) {
    switch (mode) {
      case PowerMode.tracking:
        return BleConfig.gpsIntervalHigh;
      case PowerMode.normal:
        return BleConfig.gpsIntervalNormal;
      case PowerMode.lowPower:
        return BleConfig.gpsIntervalLow;
      case PowerMode.ultraLowPower:
        return BleConfig.gpsIntervalUltraLow;
    }
  }
}
