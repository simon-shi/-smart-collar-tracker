import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/location_provider.dart';
import '../../../config/theme.dart';

class MiniMapWidget extends ConsumerWidget {
  final VoidCallback? onTap;

  const MiniMapWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(selectedPetLocationProvider);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: Stack(
            children: [
              // Map placeholder (in production, use GoogleMap widget here)
              Container(
                color: Colors.grey[200],
                child: Center(
                  child: locationAsync.when(
                    data: (location) => location != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 48,
                              ),
                              Text(
                                '${location.latitude.toStringAsFixed(4)}, '
                                '${location.longitude.toStringAsFixed(4)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          )
                        : const _NoLocationView(),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const _NoLocationView(),
                  ),
                ),
              ),
              // Overlay button
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Full Map',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoLocationView extends StatelessWidget {
  const _NoLocationView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_off, color: Colors.grey[400], size: 40),
        const SizedBox(height: 8),
        Text(
          'Location unavailable',
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    );
  }
}
