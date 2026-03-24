import 'package:equatable/equatable.dart';

enum DeviceStatus { connected, disconnected, connecting, syncing, updating }
enum PowerMode { normal, lowPower, ultraLowPower, tracking }

class Device extends Equatable {
  final String id;
  final String name;
  final String macAddress;
  final String firmwareVersion;
  final String hardwareVersion;
  final int batteryLevel;
  final DeviceStatus status;
  final PowerMode powerMode;
  final int gpsIntervalSeconds;
  final bool ledEnabled;
  final bool buzzerEnabled;
  final DateTime? lastSeen;
  final int? rssi;
  final String? petId;

  const Device({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.firmwareVersion,
    required this.hardwareVersion,
    required this.batteryLevel,
    this.status = DeviceStatus.disconnected,
    this.powerMode = PowerMode.normal,
    this.gpsIntervalSeconds = 30,
    this.ledEnabled = false,
    this.buzzerEnabled = false,
    this.lastSeen,
    this.rssi,
    this.petId,
  });

  bool get isConnected => status == DeviceStatus.connected;

  bool get isBatteryLow => batteryLevel < 20;
  bool get isBatteryCritical => batteryLevel < 10;

  Device copyWith({
    String? id,
    String? name,
    String? macAddress,
    String? firmwareVersion,
    String? hardwareVersion,
    int? batteryLevel,
    DeviceStatus? status,
    PowerMode? powerMode,
    int? gpsIntervalSeconds,
    bool? ledEnabled,
    bool? buzzerEnabled,
    DateTime? lastSeen,
    int? rssi,
    String? petId,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      powerMode: powerMode ?? this.powerMode,
      gpsIntervalSeconds: gpsIntervalSeconds ?? this.gpsIntervalSeconds,
      ledEnabled: ledEnabled ?? this.ledEnabled,
      buzzerEnabled: buzzerEnabled ?? this.buzzerEnabled,
      lastSeen: lastSeen ?? this.lastSeen,
      rssi: rssi ?? this.rssi,
      petId: petId ?? this.petId,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      macAddress: json['macAddress'] as String,
      firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.0',
      hardwareVersion: json['hardwareVersion'] as String? ?? '1.0',
      batteryLevel: json['batteryLevel'] as int? ?? 0,
      status: DeviceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeviceStatus.disconnected,
      ),
      powerMode: PowerMode.values.firstWhere(
        (e) => e.name == json['powerMode'],
        orElse: () => PowerMode.normal,
      ),
      gpsIntervalSeconds: json['gpsIntervalSeconds'] as int? ?? 30,
      petId: json['petId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'macAddress': macAddress,
      'firmwareVersion': firmwareVersion,
      'hardwareVersion': hardwareVersion,
      'batteryLevel': batteryLevel,
      'status': status.name,
      'powerMode': powerMode.name,
      'gpsIntervalSeconds': gpsIntervalSeconds,
      'petId': petId,
    };
  }

  @override
  List<Object?> get props => [id, macAddress, status, batteryLevel, rssi];
}
