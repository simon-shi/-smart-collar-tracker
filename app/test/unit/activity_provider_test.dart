import 'package:flutter_test/flutter_test.dart';

import 'package:smart_collar_tracker/models/activity.dart';

void main() {
  group('ActivityData', () {
    final testActivity = ActivityData(
      id: 'test-id',
      petId: 'pet-1',
      date: DateTime(2026, 1, 15),
      steps: 4000,
      distanceMeters: 3000,
      caloriesBurned: 200,
      activeMinutes: 60,
      restMinutes: 300,
      playMinutes: 30,
      sleepMinutes: 480,
      stepGoal: 5000,
    );

    test('stepGoalProgress should be between 0 and 1', () {
      expect(testActivity.stepGoalProgress, greaterThanOrEqualTo(0.0));
      expect(testActivity.stepGoalProgress, lessThanOrEqualTo(1.0));
    });

    test('stepGoalProgress should be 0.8 for 4000 out of 5000', () {
      expect(testActivity.stepGoalProgress, closeTo(0.8, 0.001));
    });

    test('stepGoalReached should be false when steps < goal', () {
      expect(testActivity.stepGoalReached, isFalse);
    });

    test('stepGoalReached should be true when steps >= goal', () {
      final reached = testActivity.copyWith(steps: 5000);
      // We need to use fromJson for copyWith since we don't have it
      final reachedActivity = ActivityData(
        id: testActivity.id,
        petId: testActivity.petId,
        date: testActivity.date,
        steps: 5000,
        distanceMeters: testActivity.distanceMeters,
        caloriesBurned: testActivity.caloriesBurned,
        activeMinutes: testActivity.activeMinutes,
        restMinutes: testActivity.restMinutes,
        playMinutes: testActivity.playMinutes,
        sleepMinutes: testActivity.sleepMinutes,
        stepGoal: testActivity.stepGoal,
      );
      expect(reachedActivity.stepGoalReached, isTrue);
    });

    test('totalMinutes should sum all activity types', () {
      expect(
        testActivity.totalMinutes,
        equals(60 + 300 + 30 + 480),
      );
    });

    test('fromJson/toJson round trip', () {
      final json = testActivity.toJson();
      final restored = ActivityData.fromJson(json);
      expect(restored.id, equals(testActivity.id));
      expect(restored.steps, equals(testActivity.steps));
      expect(restored.caloriesBurned, equals(testActivity.caloriesBurned));
      expect(restored.activeMinutes, equals(testActivity.activeMinutes));
    });
  });
}
