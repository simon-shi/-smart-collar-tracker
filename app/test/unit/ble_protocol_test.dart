import 'package:flutter_test/flutter_test.dart';

import 'package:smart_collar_tracker/services/ble/ble_protocol.dart';
import 'package:smart_collar_tracker/config/ble_config.dart';

void main() {
  group('BleProtocol', () {
    group('encodeCommand', () {
      test('should encode LED on command', () {
        final cmd = BleProtocol.encodeLedOn();
        expect(cmd.first, equals(BleConfig.cmdLedOn));
        expect(cmd.length, equals(1));
      });

      test('should encode LED off command', () {
        final cmd = BleProtocol.encodeLedOff();
        expect(cmd.first, equals(BleConfig.cmdLedOff));
      });

      test('should encode buzzer on command', () {
        final cmd = BleProtocol.encodeBuzzerOn();
        expect(cmd.first, equals(BleConfig.cmdBuzzerOn));
      });

      test('should encode GPS interval command', () {
        final cmd = BleProtocol.encodeGpsInterval(30);
        expect(cmd.first, equals(BleConfig.cmdSetGpsInterval));
        expect(cmd.length, equals(3));
        // 30 = 0x001E -> [0x00, 0x1E]
        expect(cmd[1], equals(0x00));
        expect(cmd[2], equals(0x1E));
      });

      test('should encode GPS interval for large value', () {
        final cmd = BleProtocol.encodeGpsInterval(600);
        expect(cmd.first, equals(BleConfig.cmdSetGpsInterval));
        // 600 = 0x0258 -> [0x02, 0x58]
        expect(cmd[1], equals(0x02));
        expect(cmd[2], equals(0x58));
      });

      test('should encode power mode command', () {
        final cmd = BleProtocol.encodePowerMode(BleConfig.powerModeLowPower);
        expect(cmd.first, equals(BleConfig.cmdSetPowerMode));
        expect(cmd[1], equals(BleConfig.powerModeLowPower));
      });

      test('should encode request sync command', () {
        final cmd = BleProtocol.encodeRequestSync();
        expect(cmd.first, equals(BleConfig.cmdRequestSync));
      });
    });

    group('parseLocationData', () {
      test('should return null for data too short', () {
        final result = BleProtocol.parseLocationData(
          [0, 1, 2, 3],
          petId: 'pet1',
        );
        expect(result, isNull);
      });

      test('should parse valid location data (20 bytes)', () {
        // lat = 37.7749 degrees * 1e7 = 377749000 = 0x167E20A8
        // lon = -122.4194 degrees * 1e7 = -1224194000 = 0xB6A7E7F0
        final lat = (37.7749 * 1e7).toInt();
        final lon = (-122.4194 * 1e7).toInt();
        final data = [
          lat & 0xFF, (lat >> 8) & 0xFF, (lat >> 16) & 0xFF, (lat >> 24) & 0xFF,
          lon & 0xFF, (lon >> 8) & 0xFF, (lon >> 16) & 0xFF, (lon >> 24) & 0xFF,
          0, 0,       // alt
          0, 0,       // speed
          0, 0,       // heading
          0, 0,       // accuracy
          0, 0, 0, 1, // timestamp (1 second)
        ];
        final result = BleProtocol.parseLocationData(data, petId: 'pet1');
        expect(result, isNotNull);
        expect(result!.petId, equals('pet1'));
        expect(result.latitude, closeTo(37.7749, 0.001));
        expect(result.longitude, closeTo(-122.4194, 0.001));
      });
    });

    group('parseActivityData', () {
      test('should return null for data too short', () {
        final result = BleProtocol.parseActivityData([0, 1, 2]);
        expect(result, isNull);
      });

      test('should parse valid activity data (12 bytes)', () {
        // steps = 5000 = 0x00001388
        final steps = 5000;
        final data = [
          steps & 0xFF, (steps >> 8) & 0xFF,
          (steps >> 16) & 0xFF, (steps >> 24) & 0xFF,
          200, 0,   // calories = 200
          60, 0,    // activeMinutes = 60
          120, 0,   // restMinutes = 120
          30, 0,    // playMinutes = 30
        ];
        final result = BleProtocol.parseActivityData(data);
        expect(result, isNotNull);
        expect(result!['steps'], equals(5000));
        expect(result['calories'], equals(200.0));
        expect(result['activeMinutes'], equals(60));
      });
    });

    group('parseDeviceStatus', () {
      test('should return null for data too short', () {
        final result = BleProtocol.parseDeviceStatus([0, 1, 2]);
        expect(result, isNull);
      });

      test('should parse valid device status (8 bytes)', () {
        final data = [
          75,    // battery = 75%
          80,    // signal = 80
          0,     // powerMode = normal
          30, 0, // gpsInterval = 30
          0x03,  // flags: LED=1, buzzer=1
          1,     // firmwareMajor = 1
          5,     // firmwareMinor = 5
        ];
        final result = BleProtocol.parseDeviceStatus(data);
        expect(result, isNotNull);
        expect(result!['batteryLevel'], equals(75));
        expect(result['powerMode'], equals(0));
        expect(result['gpsIntervalSeconds'], equals(30));
        expect(result['ledEnabled'], isTrue);
        expect(result['buzzerEnabled'], isTrue);
        expect(result['firmwareMajor'], equals(1));
        expect(result['firmwareMinor'], equals(5));
      });
    });

    group('estimateDistanceFromRssi', () {
      test('should return -1 for RSSI of 0', () {
        expect(BleProtocol.estimateDistanceFromRssi(0), equals(-1));
      });

      test('should return positive distance for valid RSSI', () {
        final distance = BleProtocol.estimateDistanceFromRssi(-70);
        expect(distance, greaterThan(0));
      });
    });
  });
}
