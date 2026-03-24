import 'package:flutter/material.dart';

import '../../models/geofence.dart';
import '../../utils/formatters.dart';

class GeofenceAlertDialog extends StatelessWidget {
  final String petName;
  final Geofence geofence;
  final String eventType; // 'enter' or 'exit'
  final DateTime timestamp;
  final VoidCallback? onViewMap;
  final VoidCallback? onDismiss;

  const GeofenceAlertDialog({
    super.key,
    required this.petName,
    required this.geofence,
    required this.eventType,
    required this.timestamp,
    this.onViewMap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isEnter = eventType == 'enter';
    final color = isEnter ? Colors.orange : Colors.red;
    final icon = isEnter ? Icons.login : Icons.logout;
    final action = isEnter ? 'entered' : 'left';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            'Geofence Alert',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: [
                TextSpan(
                  text: petName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' has $action '),
                TextSpan(
                  text: geofence.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.dateTime(timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
        if (onViewMap != null)
          ElevatedButton.icon(
            onPressed: onViewMap,
            icon: const Icon(Icons.map),
            label: const Text('View on Map'),
          ),
      ],
    );
  }
}
