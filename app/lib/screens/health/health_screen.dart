import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/health_provider.dart';
import '../../providers/pet_provider.dart';
import '../../models/health_report.dart';
import '../../router/app_router.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Health')),
      body: petId == null
          ? const Center(child: Text('No pet selected'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Active anomalies
                  ref.watch(healthAnomaliesProvider(petId)).when(
                    data: (anomalies) {
                      final active =
                          anomalies.where((a) => !a.isResolved).toList();
                      if (active.isEmpty) return const SizedBox.shrink();
                      return Card(
                        color:
                            Theme.of(context).colorScheme.errorContainer,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.warning_amber),
                              title: Text(
                                '${active.length} Active Alert${active.length > 1 ? "s" : ""}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              trailing: TextButton(
                                onPressed: () =>
                                    context.push(Routes.anomalyAlert),
                                child: const Text('View All'),
                              ),
                            ),
                            ...active.take(2).map(
                                  (a) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.circle,
                                        size: 8, color: Colors.red),
                                    title: Text(a.description),
                                    subtitle: Text(
                                        Formatters.dateTime(a.detectedAt)),
                                  ),
                                ),
                          ],
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  // Health reports
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text(
                            'Health Reports',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: TextButton(
                            onPressed: () => context.push(Routes.healthReport),
                            child: const Text('View All'),
                          ),
                        ),
                        ref.watch(healthReportsProvider(petId)).when(
                          data: (reports) {
                            if (reports.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No reports available yet'),
                              );
                            }
                            return Column(
                              children: reports.take(3).map((r) {
                                return ListTile(
                                  leading: _HealthStatusIcon(
                                      status: r.overallStatus),
                                  title: Text(
                                    '${r.period.capitalize()} Report',
                                  ),
                                  subtitle: Text(
                                    '${Formatters.date(r.periodStart)} – '
                                    '${Formatters.date(r.periodEnd)}',
                                  ),
                                  onTap: () =>
                                      context.push(Routes.healthReport),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) =>
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Failed to load reports'),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class _HealthStatusIcon extends StatelessWidget {
  final HealthStatus status;
  const _HealthStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case HealthStatus.normal:
        color = Colors.green;
        icon = Icons.check_circle;
      case HealthStatus.warning:
        color = Colors.orange;
        icon = Icons.warning;
      case HealthStatus.critical:
        color = Colors.red;
        icon = Icons.error;
    }
    return Icon(icon, color: color);
  }
}
