import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../providers/device_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../config/theme.dart';

class PetStatusCard extends ConsumerWidget {
  final Pet pet;

  const PetStatusCard({super.key, required this.pet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider).valueOrNull;
    final locationAsync = ref.watch(selectedPetLocationProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Pet avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: pet.photoUrl != null
                      ? NetworkImage(pet.photoUrl!)
                      : null,
                  child: pet.photoUrl == null
                      ? const Icon(Icons.pets, color: AppColors.primary, size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                // Pet info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        pet.breed.isNotEmpty
                            ? '${pet.breed} · ${pet.ageDisplay}'
                            : pet.ageDisplay,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: device?.isConnected == true
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: device?.isConnected == true
                            ? AppColors.success
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        device?.isConnected == true ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: device?.isConnected == true
                              ? AppColors.success
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatusItem(
                  icon: Icons.battery_full,
                  label: 'Battery',
                  value: device != null ? '${device.batteryLevel}%' : '--',
                  color: _batteryColor(device?.batteryLevel ?? 0),
                ),
                _StatusItem(
                  icon: Icons.signal_cellular_alt,
                  label: 'Signal',
                  value: device?.rssi != null ? '${device!.rssi} dBm' : '--',
                  color: AppColors.info,
                ),
                _StatusItem(
                  icon: Icons.gps_fixed,
                  label: 'Location',
                  value: locationAsync.valueOrNull != null ? 'Active' : 'N/A',
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _batteryColor(int level) {
    if (level >= 50) return AppColors.batteryHigh;
    if (level >= 20) return AppColors.batteryMedium;
    return AppColors.batteryLow;
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.5),
              ),
        ),
      ],
    );
  }
}
