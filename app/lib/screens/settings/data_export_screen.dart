import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  String _format = 'json';
  bool _isExporting = false;
  String? _exportStatus;

  final _dataTypes = {
    'Location History': true,
    'Activity Data': true,
    'Health Reports': true,
    'Pet Profiles': true,
    'Geofences': true,
    'Account Information': true,
  };

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _exportStatus = null;
    });

    await Future.delayed(const Duration(seconds: 2)); // Simulate API call

    if (mounted) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Export request submitted. '
            'You will receive an email with your data within 24 hours.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export My Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // GDPR info
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text(
                        'GDPR Right to Data Portability',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Under GDPR Article 20, you have the right to receive your '
                    'personal data in a portable format.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Format selection
          Text(
            'Export Format',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'json', label: Text('JSON')),
              ButtonSegment(value: 'csv', label: Text('CSV')),
            ],
            selected: {_format},
            onSelectionChanged: (v) => setState(() => _format = v.first),
          ),
          const SizedBox(height: 24),
          // Data types
          Text(
            'Select Data to Export',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: _dataTypes.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _dataTypes[entry.key] = v ?? false);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // Export button
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _export,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Requesting...' : 'Request Export'),
          ),
          if (_exportStatus != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _exportStatus!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
