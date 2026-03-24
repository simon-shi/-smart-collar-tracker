import '../../models/location.dart';
import '../../models/track_point.dart';
import 'api_client.dart';

class LocationApi {
  final ApiClient _client;

  LocationApi(this._client);

  Future<PetLocation?> getLatestLocation(String petId) async {
    final response = await _client.get('/pets/$petId/locations/latest');
    if (response.data == null) return null;
    return PetLocation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PetLocation>> getLocationHistory(
    String petId, {
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    final response = await _client.get(
      '/pets/$petId/locations',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        'limit': limit,
      },
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => PetLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TrackPoint>> getTrackReplay(
    String petId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      '/pets/$petId/locations/track',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
