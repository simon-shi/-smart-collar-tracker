import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// A widget that displays an estimated distance to the pet based on BLE RSSI.
///
/// Shows a large distance label, a signal strength bar, and a qualitative
/// proximity indicator (e.g. "Very close", "Nearby", "Far").
class DistanceIndicator extends StatelessWidget {
  /// Estimated distance in metres (from RSSI calculation).
  final double distanceMeters;

  /// Raw RSSI value in dBm. Optional; shown as a subtitle.
  final int? rssi;

  /// Whether the collar is currently connected via BLE.
  final bool isConnected;

  const DistanceIndicator({
    super.key,
    required this.distanceMeters,
    this.rssi,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = _distanceLabel();
    final quality = _signalQuality();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large distance text
            Text(
              isConnected ? _formatDistance() : 'N/A',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isConnected ? quality.color : Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isConnected ? label : 'Collar not connected',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Signal strength bar
            _SignalBar(rssi: isConnected ? (rssi ?? -100) : -100),
            if (rssi != null && isConnected) ...[
              const SizedBox(height: 6),
              Text(
                'RSSI: $rssi dBm',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDistance() {
    if (distanceMeters < 1) return '<1 m';
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(1)} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String _distanceLabel() {
    if (distanceMeters < 2) return 'Very close';
    if (distanceMeters < 10) return 'Nearby';
    if (distanceMeters < 50) return 'Close';
    if (distanceMeters < 200) return 'Moderate distance';
    return 'Far away';
  }

  _SignalQuality _signalQuality() {
    if (rssi == null) return _SignalQuality.unknown;
    if (rssi! >= -60) return _SignalQuality.excellent;
    if (rssi! >= -75) return _SignalQuality.good;
    if (rssi! >= -90) return _SignalQuality.fair;
    return _SignalQuality.poor;
  }
}

enum _SignalQuality {
  excellent,
  good,
  fair,
  poor,
  unknown;

  Color get color {
    switch (this) {
      case _SignalQuality.excellent:
        return AppColors.success;
      case _SignalQuality.good:
        return AppColors.primary;
      case _SignalQuality.fair:
        return AppColors.warning;
      case _SignalQuality.poor:
        return AppColors.error;
      case _SignalQuality.unknown:
        return Colors.grey;
    }
  }
}

/// A horizontal signal-strength indicator using 5 bars.
class _SignalBar extends StatelessWidget {
  final int rssi; // dBm

  const _SignalBar({required this.rssi});

  int get _bars {
    if (rssi >= -55) return 5;
    if (rssi >= -65) return 4;
    if (rssi >= -75) return 3;
    if (rssi >= -85) return 2;
    if (rssi >= -95) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final activeBars = _bars;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final barHeight = 8.0 + i * 4.0;
        final isActive = i < activeBars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: barHeight,
            decoration: BoxDecoration(
              color: isActive
                  ? _barColor(i)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Color _barColor(int index) {
    if (index <= 1) return AppColors.error;
    if (index <= 2) return AppColors.warning;
    return AppColors.success;
  }
}
