import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';

import '../../providers/device_provider.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';
import '../../services/ble/ble_service.dart';

class PairDeviceScreen extends ConsumerStatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  ConsumerState<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends ConsumerState<PairDeviceScreen> {
  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    await ref.read(bleServiceProvider).startScan();
  }

  Future<void> _connectDevice(ScanResult result) async {
    final success =
        await ref.read(deviceProvider.notifier).connectDevice(result);
    if (success && mounted) {
      context.go(Routes.addPet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanResults = ref.watch(scanResultsProvider);
    final connectionState = ref.watch(deviceConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair Your Collar'),
        actions: [
          TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: AppColors.primary.withOpacity(0.05),
            child: Column(
              children: [
                const Icon(
                  Icons.bluetooth_searching,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Searching for Collars',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure your collar is turned on and nearby',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Connection state
          connectionState.when(
            data: (state) => state == BleConnectionState.connecting
                ? const LinearProgressIndicator()
                : const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Device list
          Expanded(
            child: scanResults.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text('Scanning for devices...'),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _startScan,
                          child: const Text('Scan Again'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.bluetooth,
                          color: AppColors.primary,
                        ),
                        title: Text(device.device.platformName),
                        subtitle: Text(
                          'Signal: ${device.rssi} dBm',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _connectDevice(device),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 36),
                          ),
                          child: const Text('Pair'),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
