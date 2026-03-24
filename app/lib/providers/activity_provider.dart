import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../services/api/api_client.dart';
import '../utils/logger.dart';
import 'pet_provider.dart';

class ActivityApi {
  final ApiClient _client;
  ActivityApi(this._client);

  Future<ActivityData?> getDailyActivity(String petId, DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await _client.get(
      '/pets/$petId/activity',
      queryParameters: {'date': dateStr},
    );
    if (response.data == null) return null;
    return ActivityData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ActivityData>> getActivityRange(
    String petId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      '/pets/$petId/activity/range',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => ActivityData.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final activityApiProvider = Provider<ActivityApi>(
  (ref) => ActivityApi(ref.watch(apiClientProvider)),
);

final todayActivityProvider = FutureProvider.family<ActivityData?, String>(
  (ref, petId) async {
    final api = ref.watch(activityApiProvider);
    try {
      return await api.getDailyActivity(petId, DateTime.now());
    } catch (e) {
      AppLogger.error('Load today activity failed: $e');
      return null;
    }
  },
);

final weeklyActivityProvider =
    FutureProvider.family<List<ActivityData>, String>(
  (ref, petId) async {
    final api = ref.watch(activityApiProvider);
    final now = DateTime.now();
    return api.getActivityRange(
      petId,
      from: now.subtract(const Duration(days: 7)),
      to: now,
    );
  },
);

final monthlyActivityProvider =
    FutureProvider.family<List<ActivityData>, String>(
  (ref, petId) async {
    final api = ref.watch(activityApiProvider);
    final now = DateTime.now();
    return api.getActivityRange(
      petId,
      from: now.subtract(const Duration(days: 30)),
      to: now,
    );
  },
);

final selectedPetTodayActivityProvider = Provider<AsyncValue<ActivityData?>>((ref) {
  final petId = ref.watch(selectedPetIdProvider);
  if (petId == null) return const AsyncValue.data(null);
  return ref.watch(todayActivityProvider(petId));
});
