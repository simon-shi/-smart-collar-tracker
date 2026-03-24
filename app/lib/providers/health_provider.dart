import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_report.dart';
import '../services/api/api_client.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

class HealthApi {
  final ApiClient _client;
  HealthApi(this._client);

  Future<List<HealthReport>> getHealthReports(String petId) async {
    final response = await _client.get('/pets/$petId/health/reports');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => HealthReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HealthAnomaly>> getAnomalies(
    String petId, {
    bool activeOnly = true,
  }) async {
    final response = await _client.get(
      '/pets/$petId/health/anomalies',
      queryParameters: {'activeOnly': activeOnly},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => HealthAnomaly.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final healthApiProvider = Provider<HealthApi>(
  (ref) => HealthApi(ref.watch(apiClientProvider)),
);

final healthReportsProvider =
    FutureProvider.family<List<HealthReport>, String>(
  (ref, petId) async {
    final api = ref.watch(healthApiProvider);
    try {
      return await api.getHealthReports(petId);
    } catch (e) {
      AppLogger.error('Load health reports failed: $e');
      return [];
    }
  },
);

final healthAnomaliesProvider =
    FutureProvider.family<List<HealthAnomaly>, String>(
  (ref, petId) async {
    final api = ref.watch(healthApiProvider);
    try {
      return await api.getAnomalies(petId);
    } catch (e) {
      AppLogger.error('Load anomalies failed: $e');
      return [];
    }
  },
);

final activeAnomaliesCountProvider = Provider.family<int, String>((ref, petId) {
  return ref
      .watch(healthAnomaliesProvider(petId))
      .valueOrNull
      ?.where((a) => !a.isResolved)
      .length ?? 0;
});
