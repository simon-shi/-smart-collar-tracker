import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

import '../../config/ble_config.dart';
import '../../models/device.dart';
import '../../utils/logger.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  disconnecting,
}

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;
  int _reconnectAttempts = 0;
  bool _shouldAutoReconnect = false;

  final _connectionStateController =
      BehaviorSubject<BleConnectionState>.seeded(
    BleConnectionState.disconnected,
  );
  final _discoveredDevicesController =
      BehaviorSubject<List<ScanResult>>.seeded([]);
  final _rssiController = BehaviorSubject<int>.seeded(0);

  Stream<BleConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<List<ScanResult>> get discoveredDevices =>
      _discoveredDevicesController.stream;
  Stream<int> get rssiStream => _rssiController.stream;

  BleConnectionState get currentState => _connectionStateController.value;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Start scanning for Pet Collar devices
  Future<void> startScan() async {
    if (currentState == BleConnectionState.scanning) return;

    final isOn = await FlutterBluePlus.adapterState.first ==
        BluetoothAdapterState.on;
    if (!isOn) {
      AppLogger.warn('Bluetooth is not enabled');
      return;
    }

    _discoveredDevicesController.add([]);
    _connectionStateController.add(BleConnectionState.scanning);

    final results = <String, ScanResult>{};

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (scanResults) {
        for (final result in scanResults) {
          if (result.device.platformName
              .startsWith(BleConfig.deviceNamePrefix)) {
            results[result.device.remoteId.str] = result;
          }
        }
        _discoveredDevicesController.add(results.values.toList());
      },
      onError: (Object e) => AppLogger.error('Scan error: $e'),
    );

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: BleConfig.scanTimeoutSeconds),
      withServices: [Guid(BleConfig.serviceUuid)],
    );

    await Future.delayed(Duration(seconds: BleConfig.scanTimeoutSeconds));
    await stopScan();
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (currentState == BleConnectionState.scanning) {
      _connectionStateController.add(BleConnectionState.disconnected);
    }
  }

  /// Connect to a BLE device
  Future<bool> connect(BluetoothDevice device) async {
    if (currentState == BleConnectionState.connected &&
        _connectedDevice?.remoteId == device.remoteId) {
      return true;
    }

    await disconnect();
    _connectionStateController.add(BleConnectionState.connecting);
    _shouldAutoReconnect = true;

    try {
      await device.connect(
        timeout: Duration(seconds: BleConfig.connectionTimeoutSeconds),
        autoConnect: false,
      );

      _connectedDevice = device;
      _connectionStateController.add(BleConnectionState.connected);
      _reconnectAttempts = 0;

      // Listen for disconnection
      _connectionSubscription?.cancel();
      _connectionSubscription =
          device.connectionState.listen(_onConnectionStateChange);

      // Request larger MTU for better throughput
      await device.requestMtu(BleConfig.mtu);

      AppLogger.info('Connected to ${device.platformName}');
      return true;
    } catch (e) {
      AppLogger.error('Connection failed: $e');
      _connectionStateController.add(BleConnectionState.disconnected);
      return false;
    }
  }

  void _onConnectionStateChange(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      AppLogger.info('Device disconnected');
      _connectionStateController.add(BleConnectionState.disconnected);
      if (_shouldAutoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= BleConfig.maxReconnectAttempts) {
      AppLogger.warn('Max reconnect attempts reached');
      _shouldAutoReconnect = false;
      return;
    }

    _reconnectAttempts++;
    AppLogger.info(
      'Scheduling reconnect attempt $_reconnectAttempts in ${BleConfig.reconnectDelaySeconds}s',
    );

    Future.delayed(
      Duration(seconds: BleConfig.reconnectDelaySeconds),
      () {
        if (_shouldAutoReconnect && _connectedDevice != null) {
          connect(_connectedDevice!);
        }
      },
    );
  }

  Future<void> disconnect() async {
    _shouldAutoReconnect = false;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_connectedDevice != null) {
      _connectionStateController.add(BleConnectionState.disconnecting);
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        AppLogger.error('Disconnect error: $e');
      }
      _connectedDevice = null;
    }
    _connectionStateController.add(BleConnectionState.disconnected);
  }

  /// Get a specific GATT characteristic
  Future<BluetoothCharacteristic?> getCharacteristic(
    String characteristicUuid,
  ) async {
    if (_connectedDevice == null) return null;

    try {
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid == Guid(BleConfig.serviceUuid)) {
          for (final char in service.characteristics) {
            if (char.uuid == Guid(characteristicUuid)) {
              return char;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('Get characteristic error: $e');
    }
    return null;
  }

  /// Read a characteristic value
  Future<List<int>?> readCharacteristic(String characteristicUuid) async {
    final char = await getCharacteristic(characteristicUuid);
    if (char == null) return null;
    try {
      return await char.read();
    } catch (e) {
      AppLogger.error('Read characteristic error: $e');
      return null;
    }
  }

  /// Write to a characteristic
  Future<bool> writeCharacteristic(
    String characteristicUuid,
    List<int> value, {
    bool withResponse = true,
  }) async {
    final char = await getCharacteristic(characteristicUuid);
    if (char == null) return false;
    try {
      await char.write(
        value,
        withoutResponse: !withResponse,
      );
      return true;
    } catch (e) {
      AppLogger.error('Write characteristic error: $e');
      return false;
    }
  }

  /// Subscribe to characteristic notifications
  Future<Stream<List<int>>?> subscribeToCharacteristic(
    String characteristicUuid,
  ) async {
    final char = await getCharacteristic(characteristicUuid);
    if (char == null) return null;
    try {
      await char.setNotifyValue(true);
      return char.lastValueStream;
    } catch (e) {
      AppLogger.error('Subscribe error: $e');
      return null;
    }
  }

  /// Read current RSSI
  Future<int> readRssi() async {
    if (_connectedDevice == null) return 0;
    try {
      final rssi = await _connectedDevice!.readRssi();
      _rssiController.add(rssi);
      return rssi;
    } catch (e) {
      AppLogger.error('Read RSSI error: $e');
      return 0;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionStateController.close();
    _discoveredDevicesController.close();
    _rssiController.close();
  }
}
