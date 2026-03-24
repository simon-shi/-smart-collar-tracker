import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/device_provider.dart';
import '../../services/ble/ble_dfu_service.dart';
import '../../config/theme.dart';

class FirmwareUpdateScreen extends ConsumerStatefulWidget {
  const FirmwareUpdateScreen({super.key});

  @override
  ConsumerState<FirmwareUpdateScreen> createState() =>
      _FirmwareUpdateScreenState();
}

class _FirmwareUpdateScreenState extends ConsumerState<FirmwareUpdateScreen> {
  DfuProgress? _progress;
  String? _selectedFilePath;
  bool _isUpdating = false;

  Future<void> _pickFirmwareFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'bin'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFilePath = result.files.single.path);
    }
  }

  Future<void> _startUpdate() async {
    if (_selectedFilePath == null) return;
    final device = ref.read(deviceProvider).valueOrNull;
    if (device?.isConnected != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device not connected')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    final dfuService = BleDfuService(ref.read(bleServiceProvider));
    dfuService.progressStream.listen((p) {
      if (mounted) setState(() => _progress = p);
    });

    await dfuService.startDfu(
      firmwareFilePath: _selectedFilePath!,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (mounted) setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Firmware Update')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current version
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.memory, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Version',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        Text(
                          device?.firmwareVersion ?? 'Unknown',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // File selection
            Text(
              'Select Firmware File',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isUpdating ? null : _pickFirmwareFile,
              icon: const Icon(Icons.folder_open),
              label: Text(
                _selectedFilePath != null
                    ? _selectedFilePath!.split('/').last
                    : 'Choose .zip or .bin file',
              ),
            ),
            const SizedBox(height: 24),
            // Progress
            if (_progress != null) ...[
              Text(
                _statusLabel(_progress!.status),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress!.percent / 100,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                '${_progress!.percent}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_progress!.totalBytes > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${(_progress!.bytesTransferred / 1024).toStringAsFixed(1)} KB '
                  '/ ${(_progress!.totalBytes / 1024).toStringAsFixed(1)} KB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_progress!.isCompleted) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Update completed successfully!',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ],
              if (_progress!.isFailed) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update failed: ${_progress!.error}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const Spacer(),
            // Start button
            ElevatedButton.icon(
              onPressed:
                  (_selectedFilePath == null || _isUpdating) ? null : _startUpdate,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.system_update),
              label: Text(_isUpdating ? 'Updating...' : 'Start Update'),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Keep the app open and device nearby during the update.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DfuStatus status) {
    switch (status) {
      case DfuStatus.initializing:
        return 'Initializing...';
      case DfuStatus.enteringDfu:
        return 'Entering DFU mode...';
      case DfuStatus.validating:
        return 'Validating firmware...';
      case DfuStatus.uploading:
        return 'Uploading firmware...';
      case DfuStatus.completed:
        return 'Update complete!';
      case DfuStatus.failed:
        return 'Update failed';
    }
  }
}
