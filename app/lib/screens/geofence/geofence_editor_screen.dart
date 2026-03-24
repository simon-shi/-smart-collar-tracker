import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/geofence_provider.dart';
import '../../providers/pet_provider.dart';
import '../../models/geofence.dart';
import '../../config/theme.dart';
import '../../utils/validators.dart';

class GeofenceEditorScreen extends ConsumerStatefulWidget {
  final String? geofenceId;

  const GeofenceEditorScreen({super.key, this.geofenceId});

  @override
  ConsumerState<GeofenceEditorScreen> createState() =>
      _GeofenceEditorScreenState();
}

class _GeofenceEditorScreenState extends ConsumerState<GeofenceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  GeofenceShape _shape = GeofenceShape.circle;
  double _radius = 200;
  bool _alertOnEnter = true;
  bool _alertOnExit = true;
  String _color = '#4CAF50';
  bool _isSaving = false;

  bool get _isEditing => widget.geofenceId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExistingGeofence();
  }

  void _loadExistingGeofence() {
    final petId = ref.read(selectedPetIdProvider);
    if (petId == null) return;
    final fences = ref.read(geofenceProvider(petId)).valueOrNull;
    final fence = fences?.firstWhere(
      (f) => f.id == widget.geofenceId,
      orElse: () => fences!.first,
    );
    if (fence != null) {
      _nameController.text = fence.name;
      _shape = fence.shape;
      _radius = fence.radiusMeters ?? 200;
      _alertOnEnter = fence.alertOnEnter;
      _alertOnExit = fence.alertOnExit;
      _color = fence.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final petId = ref.read(selectedPetIdProvider);
    if (petId == null) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text.trim(),
      'shape': _shape.name,
      'color': _color,
      'alertOnEnter': _alertOnEnter,
      'alertOnExit': _alertOnExit,
      if (_shape == GeofenceShape.circle) ...{
        'centerLatitude': 37.7749,
        'centerLongitude': -122.4194,
        'radiusMeters': _radius,
      },
    };

    final notifier = ref.read(geofenceProvider(petId).notifier);
    if (_isEditing) {
      await notifier.updateGeofence(widget.geofenceId!, data);
    } else {
      await notifier.createGeofence(data);
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Geofence' : 'New Geofence'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map area (placeholder)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Tap to set fence location'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name
              TextFormField(
                controller: _nameController,
                validator: Validators.geofenceName,
                decoration: const InputDecoration(
                  labelText: 'Fence Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              // Shape
              Text('Shape', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<GeofenceShape>(
                segments: const [
                  ButtonSegment(
                    value: GeofenceShape.circle,
                    label: Text('Circle'),
                    icon: Icon(Icons.circle_outlined),
                  ),
                  ButtonSegment(
                    value: GeofenceShape.polygon,
                    label: Text('Polygon'),
                    icon: Icon(Icons.pentagon_outlined),
                  ),
                ],
                selected: {_shape},
                onSelectionChanged: (v) =>
                    setState(() => _shape = v.first),
              ),
              if (_shape == GeofenceShape.circle) ...[
                const SizedBox(height: 16),
                Text(
                  'Radius: ${_radius.toStringAsFixed(0)} m',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 5000,
                  divisions: 99,
                  label: '${_radius.toStringAsFixed(0)}m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
              ],
              const SizedBox(height: 16),
              // Color
              Text('Color', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  '#4CAF50', '#2196F3', '#FF9800', '#F44336',
                  '#9C27B0', '#00BCD4', '#FF5722', '#607D8B',
                ].map((c) {
                  final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _color == c
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Alerts
              Text('Alerts', style: Theme.of(context).textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert when pet enters'),
                value: _alertOnEnter,
                onChanged: (v) => setState(() => _alertOnEnter = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert when pet leaves'),
                value: _alertOnExit,
                onChanged: (v) => setState(() => _alertOnExit = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Update Geofence' : 'Create Geofence'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
