import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/location_provider.dart';
import '../../providers/pet_provider.dart';
import '../../config/theme.dart';
import '../../router/app_router.dart';

class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(selectedPetLocationProvider);
    final pet = ref.watch(selectedPetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${pet?.name ?? "Pet"} - Live Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Track Replay',
            onPressed: () => context.push(Routes.trackReplay),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map widget placeholder
          Container(
            color: Colors.grey[300],
            child: Center(
              child: locationAsync.when(
                data: (location) => location != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 64,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '📍 ${location.latitude.toStringAsFixed(6)},\n'
                            '    ${location.longitude.toStringAsFixed(6)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Updated: ${_formatTime(location.timestamp)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_off, size: 64, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Waiting for GPS signal...'),
                        ],
                      ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
          ),
          // Map controls
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {},
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  onPressed: () {},
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          // Map type toggle
          Positioned(
            top: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _MapTypeButton(
                      icon: Icons.map,
                      label: 'Normal',
                      isSelected: true,
                      onTap: () {},
                    ),
                    _MapTypeButton(
                      icon: Icons.satellite_alt,
                      label: 'Satellite',
                      isSelected: false,
                      onTap: () {},
                    ),
                    _MapTypeButton(
                      icon: Icons.terrain,
                      label: 'Terrain',
                      isSelected: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.findPet),
        icon: const Icon(Icons.location_searching),
        label: const Text('Find Pet'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _MapTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapTypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : Colors.grey,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
