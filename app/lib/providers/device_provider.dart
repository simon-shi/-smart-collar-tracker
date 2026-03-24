import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/api/api_client.dart';
import '../services/api/device_api.dart';
import '../services/ble/ble_service.dart';
import '../services/ble/ble_protocol.dart';
import '../services/ble/ble_data_parser.dart';
import '../config/ble_config.dart';
import '../utils/logger.dart';

final deviceApiProvider = Provider<DeviceApi>(
  (ref) => DeviceApi(ref.watch(apiClientProvider)),
);

final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

class DeviceNotifier extends StateNotifier<AsyncValue<Device?>> {
  final BleService _bleService;
  final DeviceApi _deviceApi;
  StreamSubscription? _statusSubscription;

  DeviceNotifier(this._bleService, this._deviceApi)
      : super(const AsyncValue.data(null));

  /// Connect to a BLE device discovered during scan
  Future<bool> connectDevice(ScanResult scanResult) async {
    state = const AsyncValue.loading();
    try {
      final connected = await _bleService.connect(scanResult.device);
      if (!connected) {
        state = AsyncValue.error('Connection failed', StackTrace.current);
        return false;
      }

      // Read device status
      final statusData = await _bleService.readCharacteristic(
        BleConfig.deviceStatusCharUuid,
      );
      Device? device;
      if (statusData != null) {
        final parsed = BleDataParser.parseDeviceStatus(statusData);
        if (parsed != null) {
          device = Device(
            id: scanResult.device.remoteId.str,
            name: scanResult.device.platformName,
            macAddress: scanResult.device.remoteId.str,
            firmwareVersion:
                '${parsed['firmwareMajor']}.${parsed['firmwareMinor']}',
            hardwareVersion: '1.0',
            batteryLevel: parsed['batteryLevel'] as int,
            status: DeviceStatus.connected,
            powerMode: PowerMode.values[parsed['powerMode'] as int],
            gpsIntervalSeconds: parsed['gpsIntervalSeconds'] as int,
            rssi: scanResult.rssi,
          );
        }
      }

      device ??= Device(
        id: scanResult.device.remoteId.str,
        name: scanResult.device.platformName,
        macAddress: scanResult.device.remoteId.str,
        firmwareVersion: '1.0.0',
        hardwareVersion: '1.0',
        batteryLevel: 100,
        status: DeviceStatus.connected,
        rssi: scanResult.rssi,
      );

      state = AsyncValue.data(device);
      _startStatusMonitoring();
      return true;
    } catch (e, st) {
      AppLogger.error('Connect device failed: $e');
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void _startStatusMonitoring() {
    _statusSubscription?.cancel();
    // Poll device status every 30 seconds
    _statusSubscription = Stream.periodic(
      const Duration(seconds: 30),
    ).listen((_) => _refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final statusData = await _bleService.readCharacteristic(
      BleConfig.deviceStatusCharUuid,
    );
    if (statusData == null) return;

    final parsed = BleDataParser.parseDeviceStatus(statusData);
    if (parsed == null) return;

    final rssi = await _bleService.readRssi();
    state = AsyncValue.data(current.copyWith(
      batteryLevel: parsed['batteryLevel'] as int,
      powerMode: PowerMode.values[parsed['powerMode'] as int],
      gpsIntervalSeconds: parsed['gpsIntervalSeconds'] as int,
      lastSeen: DateTime.now(),
      rssi: rssi,
    ));
  }

  Future<void> disconnect() async {
    _statusSubscription?.cancel();
    await _bleService.disconnect();
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(status: DeviceStatus.disconnected),
      );
    }
  }

  Future<bool> sendLedCommand(bool on) async {
    final command = on
        ? BleProtocol.encodeLedOn()
        : BleProtocol.encodeLedOff();
    return _bleService.writeCharacteristic(
      BleConfig.deviceControlCharUuid,
      command,
    );
  }

  Future<bool> sendBuzzerCommand(bool on) async {
    final command = on
        ? BleProtocol.encodeBuzzerOn()
        : BleProtocol.encodeBuzzerOff();
    return _bleService.writeCharacteristic(
      BleConfig.deviceControlCharUuid,
      command,
    );
  }

  Future<bool> setGpsInterval(int intervalSeconds) async {
    final command = BleProtocol.encodeGpsInterval(intervalSeconds);
    final success = await _bleService.writeCharacteristic(
      BleConfig.deviceControlCharUuid,
      command,
    );
    if (success) {
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(gpsIntervalSeconds: intervalSeconds),
        );
      }
    }
    return success;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

final deviceProvider =
    StateNotifierProvider<DeviceNotifier, AsyncValue<Device?>>(
  (ref) => DeviceNotifier(
    ref.watch(bleServiceProvider),
    ref.watch(deviceApiProvider),
  ),
);

final deviceConnectionStateProvider = StreamProvider<BleConnectionState>(
  (ref) => ref.watch(bleServiceProvider).connectionState,
);

final scanResultsProvider = StreamProvider<List<ScanResult>>(
  (ref) => ref.watch(bleServiceProvider).discoveredDevices,
);
