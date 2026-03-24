import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/geofence_provider.dart';
import '../../providers/pet_provider.dart';
import '../../models/geofence.dart';
import '../../utils/formatters.dart';

class GeofenceHistoryScreen extends ConsumerWidget {
  final String geofenceId;

  const GeofenceHistoryScreen({super.key, required this.geofenceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider) ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Entry / Exit History')),
      body: ref
          .watch(geofenceHistoryProvider((petId: petId, geofenceId: geofenceId)))
          .when(
            data: (events) {
              if (events.isEmpty) {
                return const Center(child: Text('No history yet'));
              }
              return ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final isEnter = event.eventType == 'enter';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (isEnter
                              ? Colors.green
                              : Colors.orange)
                          .withOpacity(0.1),
                      child: Icon(
                        isEnter ? Icons.login : Icons.logout,
                        color: isEnter ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(isEnter ? 'Entered' : 'Left'),
                    subtitle: Text(
                      Formatters.dateTime(event.timestamp),
                    ),
                    trailing: Text(
                      '${event.latitude.toStringAsFixed(4)}, '
                      '${event.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
    );
  }
}
