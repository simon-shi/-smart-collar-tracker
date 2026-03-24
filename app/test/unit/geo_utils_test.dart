import 'package:flutter_test/flutter_test.dart';

import 'package:smart_collar_tracker/utils/geo_utils.dart';

void main() {
  group('GeoUtils', () {
    group('haversineDistance', () {
      test('should return 0 for same point', () {
        final distance = GeoUtils.haversineDistance(
          37.7749, -122.4194, 37.7749, -122.4194,
        );
        expect(distance, closeTo(0.0, 0.001));
      });

      test('should calculate distance between SF and LA', () {
        // San Francisco to Los Angeles ~559km
        final distance = GeoUtils.haversineDistance(
          37.7749, -122.4194, // SF
          34.0522, -118.2437, // LA
        );
        expect(distance, greaterThan(550000));
        expect(distance, lessThan(570000));
      });

      test('should handle antipodal points', () {
        final distance = GeoUtils.haversineDistance(
          0.0, 0.0, 0.0, 180.0,
        );
        expect(distance, closeTo(20037508.34, 100));
      });
    });

    group('bearing', () {
      test('should return 0 (north) for northward bearing', () {
        final b = GeoUtils.bearing(0, 0, 10, 0);
        expect(b, closeTo(0.0, 0.1));
      });

      test('should return ~90 (east) for eastward bearing', () {
        final b = GeoUtils.bearing(0, 0, 0, 10);
        expect(b, closeTo(90.0, 1.0));
      });

      test('should return ~180 (south) for southward bearing', () {
        final b = GeoUtils.bearing(10, 0, 0, 0);
        expect(b, closeTo(180.0, 0.1));
      });

      test('should return ~270 (west) for westward bearing', () {
        final b = GeoUtils.bearing(0, 10, 0, 0);
        expect(b, closeTo(270.0, 1.0));
      });
    });

    group('isInsideCircle', () {
      test('should return true for point inside circle', () {
        expect(
          GeoUtils.isInsideCircle(37.7750, -122.4194, 37.7749, -122.4194, 100),
          isTrue,
        );
      });

      test('should return false for point outside circle', () {
        expect(
          GeoUtils.isInsideCircle(37.8000, -122.4194, 37.7749, -122.4194, 100),
          isFalse,
        );
      });
    });

    group('isInsidePolygon', () {
      const square = [
        (lat: 0.0, lon: 0.0),
        (lat: 1.0, lon: 0.0),
        (lat: 1.0, lon: 1.0),
        (lat: 0.0, lon: 1.0),
      ];

      test('should return true for point inside polygon', () {
        expect(
          GeoUtils.isInsidePolygon(0.5, 0.5, square),
          isTrue,
        );
      });

      test('should return false for point outside polygon', () {
        expect(
          GeoUtils.isInsidePolygon(2.0, 2.0, square),
          isFalse,
        );
      });

      test('should return false for polygon with fewer than 3 vertices', () {
        expect(
          GeoUtils.isInsidePolygon(
            0.5, 0.5, [(lat: 0.0, lon: 0.0), (lat: 1.0, lon: 0.0)],
          ),
          isFalse,
        );
      });
    });

    group('formatDistance', () {
      test('should format meters below 1000', () {
        expect(GeoUtils.formatDistance(500), equals('500 m'));
      });

      test('should format km for distances >= 1000', () {
        expect(GeoUtils.formatDistance(1500), equals('1.50 km'));
      });

      test('should format feet for imperial below 1000', () {
        expect(GeoUtils.formatDistance(100, imperial: true), contains('ft'));
      });

      test('should format miles for imperial >= 1000 ft', () {
        expect(GeoUtils.formatDistance(2000, imperial: true), contains('mi'));
      });
    });

    group('bearingToCardinal', () {
      test('returns N for bearing 0', () {
        expect(GeoUtils.bearingToCardinal(0), equals('N'));
      });

      test('returns E for bearing 90', () {
        expect(GeoUtils.bearingToCardinal(90), equals('E'));
      });

      test('returns S for bearing 180', () {
        expect(GeoUtils.bearingToCardinal(180), equals('S'));
      });

      test('returns W for bearing 270', () {
        expect(GeoUtils.bearingToCardinal(270), equals('W'));
      });
    });
  });
}
