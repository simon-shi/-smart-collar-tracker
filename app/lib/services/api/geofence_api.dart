import '../../models/geofence.dart';
import 'api_client.dart';

class GeofenceApi {
  final ApiClient _client;

  GeofenceApi(this._client);

  Future<List<Geofence>> getGeofences(String petId) async {
    final response = await _client.get('/pets/$petId/geofences');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Geofence.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Geofence> createGeofence(
    String petId,
    Map<String, dynamic> geofenceData,
  ) async {
    final response = await _client.post(
      '/pets/$petId/geofences',
      data: geofenceData,
    );
    return Geofence.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Geofence> updateGeofence(
    String petId,
    String geofenceId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _client.put(
      '/pets/$petId/geofences/$geofenceId',
      data: updates,
    );
    return Geofence.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteGeofence(String petId, String geofenceId) async {
    await _client.delete('/pets/$petId/geofences/$geofenceId');
  }

  Future<List<GeofenceEvent>> getGeofenceHistory(
    String petId,
    String geofenceId, {
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/pets/$petId/geofences/$geofenceId/history',
      queryParameters: {'limit': limit},
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => GeofenceEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
