import 'dart:async';

import '../../config/ble_config.dart';
import '../../utils/logger.dart';
import 'ble_service.dart';

/// Handles Nordic DFU (Device Firmware Update) over BLE
class BleDfuService {
  final BleService _bleService;

  final _progressController = StreamController<DfuProgress>.broadcast();
  Stream<DfuProgress> get progressStream => _progressController.stream;

  BleDfuService(this._bleService);

  /// Start firmware update via Nordic DFU protocol
  Future<bool> startDfu({
    required String firmwareFilePath,
    void Function(DfuProgress)? onProgress,
  }) async {
    if (!_bleService.currentState.isConnected) {
      AppLogger.error('Cannot start DFU: device not connected');
      return false;
    }

    AppLogger.info('Starting DFU update from: $firmwareFilePath');
    _emitProgress(DfuProgress(status: DfuStatus.initializing, percent: 0));

    try {
      // Phase 1: Enter DFU bootloader mode
      _emitProgress(DfuProgress(status: DfuStatus.enteringDfu, percent: 5));
      await _enterDfuMode();
      await Future.delayed(const Duration(seconds: 3));

      // Phase 2: Verify firmware file
      _emitProgress(DfuProgress(status: DfuStatus.validating, percent: 10));
      final isValid = await _validateFirmwareFile(firmwareFilePath);
      if (!isValid) {
        _emitProgress(
          DfuProgress(
            status: DfuStatus.failed,
            percent: 0,
            error: 'Invalid firmware file',
          ),
        );
        return false;
      }

      // Phase 3: Upload firmware
      _emitProgress(DfuProgress(status: DfuStatus.uploading, percent: 15));
      await _uploadFirmware(firmwareFilePath, onProgress);

      // Phase 4: Complete
      _emitProgress(DfuProgress(status: DfuStatus.completed, percent: 100));
      AppLogger.info('DFU completed successfully');
      return true;
    } catch (e) {
      AppLogger.error('DFU failed: $e');
      _emitProgress(
        DfuProgress(
          status: DfuStatus.failed,
          percent: 0,
          error: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> _enterDfuMode() async {
    // Send reboot-to-DFU command
    await _bleService.writeCharacteristic(
      BleConfig.deviceControlCharUuid,
      [0xFE], // DFU enter command
    );
  }

  Future<bool> _validateFirmwareFile(String filePath) async {
    // Validate .zip or .bin file exists and has correct signature
    // In production this would check the Nordic DFU init packet signature
    AppLogger.debug('Validating firmware: $filePath');
    return true;
  }

  Future<void> _uploadFirmware(
    String filePath,
    void Function(DfuProgress)? onProgress,
  ) async {
    // Simulate firmware upload phases
    // In production this would use McuMgrFlutter / nordic_dfu package
    for (var i = 15; i <= 95; i += 5) {
      await Future.delayed(const Duration(milliseconds: 200));
      final progress = DfuProgress(
        status: DfuStatus.uploading,
        percent: i,
        bytesTransferred: i * 1000,
        totalBytes: 200000,
      );
      _emitProgress(progress);
      onProgress?.call(progress);
    }
  }

  void _emitProgress(DfuProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  void dispose() {
    _progressController.close();
  }
}

enum DfuStatus {
  initializing,
  enteringDfu,
  validating,
  uploading,
  completed,
  failed,
}

class DfuProgress {
  final DfuStatus status;
  final int percent;
  final int bytesTransferred;
  final int totalBytes;
  final String? error;

  const DfuProgress({
    required this.status,
    required this.percent,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.error,
  });

  bool get isCompleted => status == DfuStatus.completed;
  bool get isFailed => status == DfuStatus.failed;
  bool get isInProgress =>
      status != DfuStatus.completed && status != DfuStatus.failed;
}

extension on BleConnectionState {
  bool get isConnected => this == BleConnectionState.connected;
}
