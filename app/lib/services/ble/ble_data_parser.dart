import '../../models/activity.dart';
import '../../models/location.dart';
import 'ble_protocol.dart';

/// Parses raw BLE characteristic byte arrays into domain models
class BleDataParser {
  /// Parse location notification into PetLocation model
  static PetLocation? parseLocation(List<int> data, {required String petId}) {
    return BleProtocol.parseLocationData(data, petId: petId);
  }

  /// Parse activity notification into ActivityData fields
  static Map<String, dynamic>? parseActivity(List<int> data) {
    return BleProtocol.parseActivityData(data);
  }

  /// Parse device status read value
  static Map<String, dynamic>? parseDeviceStatus(List<int> data) {
    return BleProtocol.parseDeviceStatus(data);
  }

  /// Parse geofence alert notification
  static Map<String, dynamic>? parseGeofenceAlert(List<int> data) {
    return BleProtocol.parseGeofenceAlert(data);
  }

  /// Parse a block of offline sync data
  /// The sync format is a series of variable-length records
  /// Each record starts with: type(1) + length(1) + data(length)
  static List<Map<String, dynamic>> parseOfflineSyncBlock(List<int> data) {
    final records = <Map<String, dynamic>>[];
    var offset = 0;

    while (offset + 2 <= data.length) {
      final type = data[offset];
      final length = data[offset + 1];
      offset += 2;

      if (offset + length > data.length) break;

      final payload = data.sublist(offset, offset + length);
      offset += length;

      switch (type) {
        case 0x01: // Location record
          final loc = BleProtocol.parseLocationData(
            payload,
            petId: 'offline',
          );
          if (loc != null) {
            records.add({'type': 'location', 'data': loc});
          }
        case 0x02: // Activity record
          final activity = BleProtocol.parseActivityData(payload);
          if (activity != null) {
            records.add({'type': 'activity', 'data': activity});
          }
        default:
          // Unknown record type, skip
          break;
      }
    }

    return records;
  }
}
