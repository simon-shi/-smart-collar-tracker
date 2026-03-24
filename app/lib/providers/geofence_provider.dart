import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geofence.dart';
import '../services/api/api_client.dart';
import '../services/api/geofence_api.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

final geofenceApiProvider = Provider<GeofenceApi>(
  (ref) => GeofenceApi(ref.watch(apiClientProvider)),
);

class GeofenceNotifier extends StateNotifier<AsyncValue<List<Geofence>>> {
  final GeofenceApi _api;
  final String _petId;

  GeofenceNotifier(this._api, this._petId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final fences = await _api.getGeofences(_petId);
      state = AsyncValue.data(fences);
    } catch (e, st) {
      AppLogger.error('Load geofences failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<Geofence?> createGeofence(Map<String, dynamic> data) async {
    try {
      final fence = await _api.createGeofence(_petId, data);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, fence]);
      return fence;
    } catch (e) {
      AppLogger.error('Create geofence failed: $e');
      return null;
    }
  }

  Future<Geofence?> updateGeofence(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updated = await _api.updateGeofence(_petId, id, updates);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((f) => f.id == id ? updated : f).toList(),
      );
      return updated;
    } catch (e) {
      AppLogger.error('Update geofence failed: $e');
      return null;
    }
  }

  Future<bool> deleteGeofence(String id) async {
    try {
      await _api.deleteGeofence(_petId, id);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(current.where((f) => f.id != id).toList());
      return true;
    } catch (e) {
      AppLogger.error('Delete geofence failed: $e');
      return false;
    }
  }

  Future<void> refresh() => _load();
}

final geofenceProvider = StateNotifierProvider.family<GeofenceNotifier,
    AsyncValue<List<Geofence>>, String>(
  (ref, petId) => GeofenceNotifier(
    ref.watch(geofenceApiProvider),
    petId,
  ),
);

final geofenceHistoryProvider = FutureProvider.family<List<GeofenceEvent>,
    ({String petId, String geofenceId})>(
  (ref, params) async {
    final api = ref.watch(geofenceApiProvider);
    return api.getGeofenceHistory(params.petId, params.geofenceId);
  },
);
