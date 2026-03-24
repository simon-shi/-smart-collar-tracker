import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/device_provider.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class DeviceScreen extends ConsumerWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(deviceProvider);
    final connectionState = ref.watch(deviceConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.deviceSettings),
          ),
        ],
      ),
      body: deviceAsync.when(
        data: (device) {
          if (device == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bluetooth_searching,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No device connected'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push(Routes.pairDevice),
                    icon: const Icon(Icons.add),
                    label: const Text('Pair a Collar'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Device header card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.devices,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        device.name,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        device.macAddress,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 8),
                      connectionState.when(
                        data: (state) => Chip(
                          label: Text(state.name),
                          backgroundColor: state.name == 'connected'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: state.name == 'connected'
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Battery and signal
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.battery_full,
                          color: AppColors.success),
                      title: const Text('Battery'),
                      trailing: Text(
                        Formatters.battery(device.batteryLevel),
                        style: TextStyle(
                          color: device.isBatteryLow
                              ? AppColors.error
                              : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.signal_cellular_alt,
                          color: AppColors.info),
                      title: const Text('Signal Strength'),
                      trailing: Text(
                        device.rssi != null ? '${device.rssi} dBm' : 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading:
                          const Icon(Icons.gps_fixed, color: Colors.green),
                      title: const Text('GPS Interval'),
                      trailing: Text(
                        '${device.gpsIntervalSeconds}s',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Firmware
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.system_update_outlined),
                      title: const Text('Firmware Version'),
                      trailing: Text(device.firmwareVersion),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.memory_outlined),
                      title: const Text('Hardware Version'),
                      trailing: Text(device.hardwareVersion),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Firmware update button
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.firmwareUpdate),
                icon: const Icon(Icons.system_update),
                label: const Text('Check for Updates'),
              ),
              const SizedBox(height: 8),
              // Disconnect
              if (device.isConnected)
                TextButton(
                  onPressed: () =>
                      ref.read(deviceProvider.notifier).disconnect(),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                  child: const Text('Disconnect'),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
