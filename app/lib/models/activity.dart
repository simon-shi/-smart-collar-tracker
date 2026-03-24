import 'package:equatable/equatable.dart';

enum ActivityType { walking, running, resting, playing, sleeping, unknown }

class ActivityData extends Equatable {
  final String id;
  final String petId;
  final DateTime date;
  final int steps;
  final double distanceMeters;
  final double caloriesBurned;
  final int activeMinutes;
  final int restMinutes;
  final int playMinutes;
  final int sleepMinutes;
  final Map<String, int> activityBreakdown; // ActivityType -> minutes
  final int stepGoal;

  const ActivityData({
    required this.id,
    required this.petId,
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesBurned,
    required this.activeMinutes,
    required this.restMinutes,
    required this.playMinutes,
    required this.sleepMinutes,
    this.activityBreakdown = const {},
    this.stepGoal = 5000,
  });

  double get stepGoalProgress => steps / stepGoal.clamp(1, stepGoal);

  bool get stepGoalReached => steps >= stepGoal;

  int get totalMinutes =>
      activeMinutes + restMinutes + playMinutes + sleepMinutes;

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    return ActivityData(
      id: json['id'] as String,
      petId: json['petId'] as String,
      date: DateTime.parse(json['date'] as String),
      steps: json['steps'] as int? ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      activeMinutes: json['activeMinutes'] as int? ?? 0,
      restMinutes: json['restMinutes'] as int? ?? 0,
      playMinutes: json['playMinutes'] as int? ?? 0,
      sleepMinutes: json['sleepMinutes'] as int? ?? 0,
      activityBreakdown:
          (json['activityBreakdown'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as int),
              ) ??
              {},
      stepGoal: json['stepGoal'] as int? ?? 5000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'date': date.toIso8601String(),
      'steps': steps,
      'distanceMeters': distanceMeters,
      'caloriesBurned': caloriesBurned,
      'activeMinutes': activeMinutes,
      'restMinutes': restMinutes,
      'playMinutes': playMinutes,
      'sleepMinutes': sleepMinutes,
      'activityBreakdown': activityBreakdown,
      'stepGoal': stepGoal,
    };
  }

  @override
  List<Object?> get props => [id, petId, date, steps];
}
