import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/notification_provider.dart';
import '../../../providers/device_provider.dart';
import '../../../config/theme.dart';

class AlertBannerWidget extends ConsumerWidget {
  const AlertBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).valueOrNull;

    final alerts = <_Alert>[];

    if (device?.isBatteryCritical == true) {
      alerts.add(_Alert(
        message: 'Critical battery: ${device!.batteryLevel}%. Charge now!',
        color: AppColors.error,
        icon: Icons.battery_alert,
      ));
    } else if (device?.isBatteryLow == true) {
      alerts.add(_Alert(
        message: 'Low battery: ${device!.batteryLevel}%. Please charge soon.',
        color: AppColors.warning,
        icon: Icons.battery_2_bar,
      ));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts
          .map(
            (alert) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: alert.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: alert.color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(alert.icon, color: alert.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.message,
                      style: TextStyle(
                        color: alert.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Alert {
  final String message;
  final Color color;
  final IconData icon;

  const _Alert({
    required this.message,
    required this.color,
    required this.icon,
  });
}
