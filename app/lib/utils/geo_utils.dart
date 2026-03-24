import 'dart:math';

/// Geospatial utility functions
class GeoUtils {
  static const double _earthRadiusMeters = 6371000.0;

  /// Haversine formula to calculate great-circle distance between two points
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Calculate bearing (compass direction) from point 1 to point 2
  /// Returns bearing in degrees (0-360, 0 = North)
  static double bearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = _toRadians(lon2 - lon1);
    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);

    final y = sin(dLon) * cos(rLat2);
    final x =
        cos(rLat1) * sin(rLat2) - sin(rLat1) * cos(rLat2) * cos(dLon);

    final bearing = _toDegrees(atan2(y, x));
    return (bearing + 360) % 360;
  }

  /// Check if a point is inside a circle geofence
  static bool isInsideCircle(
    double pointLat,
    double pointLon,
    double centerLat,
    double centerLon,
    double radiusMeters,
  ) {
    final distance = haversineDistance(
      pointLat,
      pointLon,
      centerLat,
      centerLon,
    );
    return distance <= radiusMeters;
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  static bool isInsidePolygon(
    double pointLat,
    double pointLon,
    List<({double lat, double lon})> vertices,
  ) {
    if (vertices.length < 3) return false;

    var inside = false;
    final n = vertices.length;
    var j = n - 1;

    for (var i = 0; i < n; i++) {
      final vi = vertices[i];
      final vj = vertices[j];

      if ((vi.lon > pointLon) != (vj.lon > pointLon) &&
          pointLat <
              (vj.lat - vi.lat) * (pointLon - vi.lon) / (vj.lon - vi.lon) +
                  vi.lat) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Format distance for display
  static String formatDistance(double meters, {bool imperial = false}) {
    if (imperial) {
      final feet = meters * 3.28084;
      if (feet < 1000) {
        return '${feet.toStringAsFixed(0)} ft';
      } else {
        final miles = meters / 1609.34;
        return '${miles.toStringAsFixed(2)} mi';
      }
    } else {
      if (meters < 1000) {
        return '${meters.toStringAsFixed(0)} m';
      } else {
        final km = meters / 1000;
        return '${km.toStringAsFixed(2)} km';
      }
    }
  }

  /// Format speed for display
  static String formatSpeed(double metersPerSecond, {bool imperial = false}) {
    if (imperial) {
      final mph = metersPerSecond * 2.23694;
      return '${mph.toStringAsFixed(1)} mph';
    } else {
      final kmh = metersPerSecond * 3.6;
      return '${kmh.toStringAsFixed(1)} km/h';
    }
  }

  /// Get cardinal direction from bearing
  static String bearingToCardinal(double bearing) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((bearing + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
  static double _toDegrees(double radians) => radians * 180 / pi;
}
