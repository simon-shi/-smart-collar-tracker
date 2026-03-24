import 'package:equatable/equatable.dart';

enum HealthStatus { normal, warning, critical }
enum AnomalyType {
  excessiveScratching,
  limping,
  seizure,
  rapidBreathing,
  inactivity,
  unknown
}

class HealthReport extends Equatable {
  final String id;
  final String petId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String period; // 'weekly', 'monthly'
  final HealthStatus overallStatus;
  final double averageDailySteps;
  final double averageActiveMinutes;
  final double averageSleepHours;
  final List<HealthAnomaly> anomalies;
  final String? summary;
  final DateTime createdAt;

  const HealthReport({
    required this.id,
    required this.petId,
    required this.periodStart,
    required this.periodEnd,
    required this.period,
    required this.overallStatus,
    required this.averageDailySteps,
    required this.averageActiveMinutes,
    required this.averageSleepHours,
    this.anomalies = const [],
    this.summary,
    required this.createdAt,
  });

  factory HealthReport.fromJson(Map<String, dynamic> json) {
    return HealthReport(
      id: json['id'] as String,
      petId: json['petId'] as String,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      period: json['period'] as String,
      overallStatus: HealthStatus.values.firstWhere(
        (e) => e.name == json['overallStatus'],
        orElse: () => HealthStatus.normal,
      ),
      averageDailySteps:
          (json['averageDailySteps'] as num?)?.toDouble() ?? 0.0,
      averageActiveMinutes:
          (json['averageActiveMinutes'] as num?)?.toDouble() ?? 0.0,
      averageSleepHours:
          (json['averageSleepHours'] as num?)?.toDouble() ?? 0.0,
      anomalies: (json['anomalies'] as List<dynamic>?)
              ?.map((e) => HealthAnomaly.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      summary: json['summary'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'period': period,
      'overallStatus': overallStatus.name,
      'averageDailySteps': averageDailySteps,
      'averageActiveMinutes': averageActiveMinutes,
      'averageSleepHours': averageSleepHours,
      'anomalies': anomalies.map((a) => a.toJson()).toList(),
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, petId, periodStart, periodEnd];
}

class HealthAnomaly extends Equatable {
  final String id;
  final String petId;
  final AnomalyType type;
  final HealthStatus severity;
  final String description;
  final DateTime detectedAt;
  final bool isResolved;
  final DateTime? resolvedAt;

  const HealthAnomaly({
    required this.id,
    required this.petId,
    required this.type,
    required this.severity,
    required this.description,
    required this.detectedAt,
    this.isResolved = false,
    this.resolvedAt,
  });

  factory HealthAnomaly.fromJson(Map<String, dynamic> json) {
    return HealthAnomaly(
      id: json['id'] as String,
      petId: json['petId'] as String,
      type: AnomalyType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AnomalyType.unknown,
      ),
      severity: HealthStatus.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => HealthStatus.warning,
      ),
      description: json['description'] as String,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      isResolved: json['isResolved'] as bool? ?? false,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'type': type.name,
      'severity': severity.name,
      'description': description,
      'detectedAt': detectedAt.toIso8601String(),
      'isResolved': isResolved,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, type, severity, detectedAt];
}
