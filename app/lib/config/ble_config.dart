/// BLE UUIDs and GATT definitions for Smart Pet Collar
class BleConfig {
  // Device name prefix for scanning
  static const String deviceNamePrefix = 'PetCollar-';

  // Custom GATT Service
  static const String serviceUuid = '12345678-1234-5678-1234-56789abcdef0';

  // Characteristics
  static const String locationCharUuid = '12345678-1234-5678-1234-56789abcdef1';
  static const String activityCharUuid = '12345678-1234-5678-1234-56789abcdef2';
  static const String geofenceAlertCharUuid =
      '12345678-1234-5678-1234-56789abcdef3';
  static const String deviceControlCharUuid =
      '12345678-1234-5678-1234-56789abcdef4';
  static const String deviceStatusCharUuid =
      '12345678-1234-5678-1234-56789abcdef5';
  static const String offlineSyncCharUuid =
      '12345678-1234-5678-1234-56789abcdef6';

  // Device Control Commands
  static const int cmdLedOn = 0x01;
  static const int cmdLedOff = 0x02;
  static const int cmdBuzzerOn = 0x03;
  static const int cmdBuzzerOff = 0x04;
  static const int cmdRequestSync = 0x05;
  static const int cmdSetGpsInterval = 0x06;
  static const int cmdSetPowerMode = 0x07;
  static const int cmdReboot = 0x08;

  // Power Modes
  static const int powerModeNormal = 0x00;
  static const int powerModeLowPower = 0x01;
  static const int powerModeUltraLowPower = 0x02;
  static const int powerModeTracking = 0x03;

  // GPS Intervals (seconds)
  static const int gpsIntervalHigh = 5;
  static const int gpsIntervalNormal = 30;
  static const int gpsIntervalLow = 120;
  static const int gpsIntervalUltraLow = 600;

  // BLE Connection parameters
  static const int scanTimeoutSeconds = 30;
  static const int connectionTimeoutSeconds = 15;
  static const int reconnectDelaySeconds = 5;
  static const int maxReconnectAttempts = 5;

  // RSSI to distance estimation coefficients
  static const double rssiAtOneMeter = -65.0;
  static const double pathLossExponent = 2.5;

  // MTU size
  static const int mtu = 247;
}
