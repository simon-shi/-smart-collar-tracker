import 'dart:typed_data';

import '../../config/ble_config.dart';
import '../../models/location.dart';
import '../../models/activity.dart';
import '../../utils/logger.dart';
import 'ble_service.dart';

/// Encodes/decodes GATT characteristic data per the collar firmware protocol
class BleProtocol {
  /// Send a device control command
  static List<int> encodeCommand(int command, [List<int> payload = const []]) {
    final data = [command, ...payload];
    AppLogger.debug('BLE command: 0x${command.toRadixString(16)} '
        'payload: ${payload.length} bytes');
    return data;
  }

  /// Turn on LED
  static List<int> encodeLedOn() =>
      encodeCommand(BleConfig.cmdLedOn);

  /// Turn off LED
  static List<int> encodeLedOff() =>
      encodeCommand(BleConfig.cmdLedOff);

  /// Turn on buzzer
  static List<int> encodeBuzzerOn() =>
      encodeCommand(BleConfig.cmdBuzzerOn);

  /// Turn off buzzer
  static List<int> encodeBuzzerOff() =>
      encodeCommand(BleConfig.cmdBuzzerOff);

  /// Set GPS interval
  static List<int> encodeGpsInterval(int intervalSeconds) {
    final payload = [
      (intervalSeconds >> 8) & 0xFF,
      intervalSeconds & 0xFF,
    ];
    return encodeCommand(BleConfig.cmdSetGpsInterval, payload);
  }

  /// Set power mode
  static List<int> encodePowerMode(int mode) =>
      encodeCommand(BleConfig.cmdSetPowerMode, [mode]);

  /// Request offline data sync
  static List<int> encodeRequestSync() =>
      encodeCommand(BleConfig.cmdRequestSync);

  /// Parse location characteristic data (20 bytes)
  /// Format: lat(4) + lon(4) + alt(2) + speed(2) + heading(2) + accuracy(2) + timestamp(4)
  static PetLocation? parseLocationData(
    List<int> data, {
    required String petId,
  }) {
    if (data.length < 20) {
      AppLogger.warn('Location data too short: ${data.length} bytes');
      return null;
    }

    try {
      final bytes = Uint8List.fromList(data);
      final view = ByteData.view(bytes.buffer);

      final lat = view.getInt32(0, Endian.little) / 1e7;
      final lon = view.getInt32(4, Endian.little) / 1e7;
      final alt = view.getInt16(8, Endian.little).toDouble();
      final speed = view.getUint16(10, Endian.little) / 100.0;
      final heading = view.getUint16(12, Endian.little) / 100.0;
      final accuracy = view.getUint16(14, Endian.little) / 100.0;
      final tsMs = view.getUint32(16, Endian.little) * 1000;

      return PetLocation(
        id: '${petId}_${DateTime.now().millisecondsSinceEpoch}',
        petId: petId,
        latitude: lat,
        longitude: lon,
        altitude: alt,
        speed: speed,
        heading: heading,
        accuracy: accuracy,
        source: 'ble',
        timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
      );
    } catch (e) {
      AppLogger.error('Parse location error: $e');
      return null;
    }
  }

  /// Parse activity characteristic data (12 bytes)
  /// Format: steps(4) + calories(2) + activeMin(2) + restMin(2) + playMin(2)
  static Map<String, dynamic>? parseActivityData(List<int> data) {
    if (data.length < 12) {
      AppLogger.warn('Activity data too short: ${data.length} bytes');
      return null;
    }

    try {
      final bytes = Uint8List.fromList(data);
      final view = ByteData.view(bytes.buffer);

      return {
        'steps': view.getUint32(0, Endian.little),
        'calories': view.getUint16(4, Endian.little).toDouble(),
        'activeMinutes': view.getUint16(6, Endian.little),
        'restMinutes': view.getUint16(8, Endian.little),
        'playMinutes': view.getUint16(10, Endian.little),
      };
    } catch (e) {
      AppLogger.error('Parse activity error: $e');
      return null;
    }
  }

  /// Parse device status characteristic (8 bytes)
  /// Format: battery(1) + signal(1) + powerMode(1) + gpsInterval(2) + flags(1) + firmware(2)
  static Map<String, dynamic>? parseDeviceStatus(List<int> data) {
    if (data.length < 8) {
      AppLogger.warn('Status data too short: ${data.length} bytes');
      return null;
    }

    try {
      final bytes = Uint8List.fromList(data);
      final view = ByteData.view(bytes.buffer);

      final flags = view.getUint8(5);
      return {
        'batteryLevel': view.getUint8(0),
        'signalStrength': view.getUint8(1),
        'powerMode': view.getUint8(2),
        'gpsIntervalSeconds': view.getUint16(3, Endian.little),
        'ledEnabled': (flags & 0x01) != 0,
        'buzzerEnabled': (flags & 0x02) != 0,
        'firmwareMajor': view.getUint8(6),
        'firmwareMinor': view.getUint8(7),
      };
    } catch (e) {
      AppLogger.error('Parse device status error: $e');
      return null;
    }
  }

  /// Parse geofence alert characteristic (5 bytes)
  /// Format: eventType(1) + lat(4) + lon(4) -- 9 bytes min
  static Map<String, dynamic>? parseGeofenceAlert(List<int> data) {
    if (data.length < 9) return null;

    try {
      final bytes = Uint8List.fromList(data);
      final view = ByteData.view(bytes.buffer);

      return {
        'eventType': view.getUint8(0) == 0x01 ? 'enter' : 'exit',
        'latitude': view.getInt32(1, Endian.little) / 1e7,
        'longitude': view.getInt32(5, Endian.little) / 1e7,
      };
    } catch (e) {
      AppLogger.error('Parse geofence alert error: $e');
      return null;
    }
  }

  /// Estimate distance from RSSI using log-distance path loss model
  static double estimateDistanceFromRssi(int rssi) {
    if (rssi == 0) return -1;
    final ratio = rssi / BleConfig.rssiAtOneMeter;
    if (ratio < 1.0) return ratio.abs();
    return ratio.abs() *
        (10 * BleConfig.pathLossExponent / 10).toDouble();
  }
}
