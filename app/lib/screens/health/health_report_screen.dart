import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/health_provider.dart';
import '../../providers/pet_provider.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class HealthReportScreen extends ConsumerWidget {
  const HealthReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
            tooltip: 'Share Report',
          ),
        ],
      ),
      body: petId == null
          ? const Center(child: Text('No pet selected'))
          : ref.watch(healthReportsProvider(petId)).when(
                data: (reports) {
                  if (reports.isEmpty) {
                    return const Center(
                      child: Text('No health reports available'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${report.period.toUpperCase()} REPORT',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  _StatusChip(status: report.overallStatus),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${Formatters.date(report.periodStart)} – ${Formatters.date(report.periodEnd)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _ReportMetric(
                                    label: 'Avg Steps',
                                    value: Formatters.steps(
                                        report.averageDailySteps.toInt()),
                                  ),
                                  _ReportMetric(
                                    label: 'Avg Active',
                                    value: Formatters.duration(Duration(
                                        minutes: report.averageActiveMinutes
                                            .toInt())),
                                  ),
                                  _ReportMetric(
                                    label: 'Avg Sleep',
                                    value:
                                        '${report.averageSleepHours.toStringAsFixed(1)}h',
                                  ),
                                ],
                              ),
                              if (report.anomalies.isNotEmpty) ...[
                                const Divider(height: 24),
                                Text(
                                  '${report.anomalies.length} anomalies detected',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (report.summary != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  report.summary!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final dynamic status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status.toString()) {
      case 'HealthStatus.normal':
        color = Colors.green;
        label = 'Normal';
      case 'HealthStatus.warning':
        color = Colors.orange;
        label = 'Warning';
      default:
        color = Colors.red;
        label = 'Critical';
    }
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String label;
  final String value;
  const _ReportMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}
