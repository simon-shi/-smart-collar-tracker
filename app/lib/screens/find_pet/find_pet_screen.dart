import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/device_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/pet_provider.dart';
import '../../services/ble/ble_protocol.dart';
import '../../config/theme.dart';
import '../../utils/geo_utils.dart';
import 'widgets/compass_widget.dart';

class FindPetScreen extends ConsumerStatefulWidget {
  const FindPetScreen({super.key});

  @override
  ConsumerState<FindPetScreen> createState() => _FindPetScreenState();
}

class _FindPetScreenState extends ConsumerState<FindPetScreen> {
  bool _ledOn = false;
  bool _buzzerOn = false;
  Timer? _rssiTimer;
  double _distance = 0;
  double _bearing = 0;

  @override
  void initState() {
    super.initState();
    _startRssiMonitoring();
  }

  void _startRssiMonitoring() {
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final rssi = await ref.read(bleServiceProvider).readRssi();
      if (mounted) {
        setState(() {
          _distance = BleProtocol.estimateDistanceFromRssi(rssi);
        });
      }
    });
  }

  Future<void> _toggleLed() async {
    final notifier = ref.read(deviceProvider.notifier);
    final success = await notifier.sendLedCommand(!_ledOn);
    if (success && mounted) setState(() => _ledOn = !_ledOn);
  }

  Future<void> _toggleBuzzer() async {
    final notifier = ref.read(deviceProvider.notifier);
    final success = await notifier.sendBuzzerCommand(!_buzzerOn);
    if (success && mounted) setState(() => _buzzerOn = !_buzzerOn);
  }

  @override
  void dispose() {
    _rssiTimer?.cancel();
    // Turn off LED and buzzer when leaving
    if (_ledOn) ref.read(deviceProvider.notifier).sendLedCommand(false);
    if (_buzzerOn) ref.read(deviceProvider.notifier).sendBuzzerCommand(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceProvider).valueOrNull;
    final pet = ref.watch(selectedPetProvider);
    final rssiStream = ref.watch(bleServiceProvider).rssiStream;

    return Scaffold(
      appBar: AppBar(title: const Text('Find My Pet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Compass
            CompassWidget(bearing: _bearing),
            const SizedBox(height: 24),
            // Distance
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Estimated Distance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _distance > 0
                          ? GeoUtils.formatDistance(_distance)
                          : 'N/A',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<int>(
                      stream: rssiStream,
                      builder: (context, snapshot) => Text(
                        'Signal: ${snapshot.data ?? 0} dBm',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Controls
            Text(
              'Collar Controls',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ControlButton(
                    icon: Icons.light_mode,
                    label: _ledOn ? 'LED: ON' : 'LED: OFF',
                    active: _ledOn,
                    enabled: device?.isConnected == true,
                    onTap: _toggleLed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ControlButton(
                    icon: Icons.volume_up,
                    label: _buzzerOn ? 'Sound: ON' : 'Sound: OFF',
                    active: _buzzerOn,
                    enabled: device?.isConnected == true,
                    onTap: _toggleBuzzer,
                  ),
                ),
              ],
            ),
            if (device?.isConnected != true) ...[
              const SizedBox(height: 16),
              const Card(
                color: Color(0xFFFFF3E0),
                child: ListTile(
                  leading: Icon(Icons.bluetooth_disabled, color: Colors.orange),
                  title: Text('Collar not connected'),
                  subtitle: Text('Connect to enable LED and sound controls'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : (enabled
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: active
                  ? Colors.white
                  : (enabled ? AppColors.primary : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : (enabled ? AppColors.primary : Colors.grey),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
