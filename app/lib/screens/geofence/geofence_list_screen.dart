import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/geofence_provider.dart';
import '../../providers/pet_provider.dart';
import '../../models/geofence.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_widget.dart';

class GeofenceListScreen extends ConsumerWidget {
  const GeofenceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geofences')),
      body: petId == null
          ? const Center(child: Text('No pet selected'))
          : ref.watch(geofenceProvider(petId)).when(
                data: (fences) {
                  if (fences.isEmpty) {
                    return EmptyState(
                      title: 'No Geofences',
                      subtitle: 'Create a safe zone for your pet',
                      icon: Icons.fence_outlined,
                      action: ElevatedButton.icon(
                        onPressed: () =>
                            context.push(Routes.geofenceEditor),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Geofence'),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: fences.length,
                    itemBuilder: (context, index) =>
                        _GeofenceCard(fence: fences[index], petId: petId),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => AppErrorWidget(
                  message: 'Failed to load geofences',
                  onRetry: () => ref.invalidate(geofenceProvider(petId)),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.geofenceEditor),
        icon: const Icon(Icons.add),
        label: const Text('Add Geofence'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _GeofenceCard extends ConsumerWidget {
  final Geofence fence;
  final String petId;

  const _GeofenceCard({required this.fence, required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor(fence.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            fence.isCircle ? Icons.circle_outlined : Icons.pentagon_outlined,
            color: color,
          ),
        ),
        title: Text(
          fence.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          fence.isCircle
              ? 'Circle · ${fence.radiusMeters?.toStringAsFixed(0) ?? "?"} m radius'
              : 'Polygon · ${fence.vertices?.length ?? 0} vertices',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: fence.isActive,
              onChanged: (v) {
                ref.read(geofenceProvider(petId).notifier).updateGeofence(
                      fence.id,
                      {'status': v ? 'active' : 'inactive'},
                    );
              },
              activeColor: AppColors.primary,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMenu(context, ref),
            ),
          ],
        ),
        onTap: () => context.push(
          '${Routes.geofenceEditor}?id=${fence.id}',
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(
        int.parse(hex.replaceFirst('#', '0xFF')),
      );
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View History'),
            onTap: () {
              Navigator.pop(context);
              context.push(
                '${Routes.geofenceHistory}?id=${fence.id}',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              context.push('${Routes.geofenceEditor}?id=${fence.id}');
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              ref
                  .read(geofenceProvider(petId).notifier)
                  .deleteGeofence(fence.id);
            },
          ),
        ],
      ),
    );
  }
}
