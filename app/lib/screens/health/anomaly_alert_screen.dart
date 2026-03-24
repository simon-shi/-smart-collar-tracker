import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/health_provider.dart';
import '../../providers/pet_provider.dart';
import '../../models/health_report.dart';
import '../../utils/formatters.dart';

class AnomalyAlertScreen extends ConsumerWidget {
  const AnomalyAlertScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Health Alerts')),
      body: petId == null
          ? const Center(child: Text('No pet selected'))
          : ref.watch(healthAnomaliesProvider(petId)).when(
                data: (anomalies) {
                  if (anomalies.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text('No health anomalies detected'),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: anomalies.length,
                    itemBuilder: (context, index) {
                      final anomaly = anomalies[index];
                      return _AnomalyCard(anomaly: anomaly);
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

class _AnomalyCard extends StatelessWidget {
  final HealthAnomaly anomaly;
  const _AnomalyCard({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(anomaly.severity);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withOpacity(0.1),
          child: Icon(
            _anomalyIcon(anomaly.type),
            color: severityColor,
          ),
        ),
        title: Text(
          _anomalyLabel(anomaly.type),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(anomaly.description),
            Text(
              Formatters.dateTime(anomaly.detectedAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: anomaly.isResolved
            ? const Chip(
                label: Text('Resolved'),
                backgroundColor: Color(0xFFE8F5E9),
              )
            : Chip(
                label: const Text('Active'),
                backgroundColor: severityColor.withOpacity(0.1),
                labelStyle: TextStyle(color: severityColor),
              ),
        isThreeLine: true,
      ),
    );
  }

  Color _severityColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.critical:
        return Colors.red;
    }
  }

  IconData _anomalyIcon(AnomalyType type) {
    switch (type) {
      case AnomalyType.excessiveScratching:
        return Icons.pan_tool;
      case AnomalyType.limping:
        return Icons.directions_walk;
      case AnomalyType.seizure:
        return Icons.warning_amber;
      case AnomalyType.rapidBreathing:
        return Icons.air;
      case AnomalyType.inactivity:
        return Icons.bedtime;
      case AnomalyType.unknown:
        return Icons.help_outline;
    }
  }

  String _anomalyLabel(AnomalyType type) {
    switch (type) {
      case AnomalyType.excessiveScratching:
        return 'Excessive Scratching';
      case AnomalyType.limping:
        return 'Limping Detected';
      case AnomalyType.seizure:
        return 'Possible Seizure';
      case AnomalyType.rapidBreathing:
        return 'Rapid Breathing';
      case AnomalyType.inactivity:
        return 'Extended Inactivity';
      case AnomalyType.unknown:
        return 'Unknown Anomaly';
    }
  }
}
