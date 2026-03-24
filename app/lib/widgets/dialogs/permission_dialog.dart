import 'package:flutter/material.dart';

class PermissionDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String permissionName;
  final VoidCallback onAllow;
  final VoidCallback? onDeny;

  const PermissionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.permissionName,
    required this.onAllow,
    this.onDeny,
  });

  static Future<void> showBluetoothPermission(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDialog(
        title: 'Bluetooth Permission Required',
        message:
            'Smart Pet Collar needs Bluetooth permission to connect to your pet\'s collar.',
        icon: Icons.bluetooth,
        permissionName: 'Bluetooth',
        onAllow: () => Navigator.of(context).pop(),
        onDeny: () => Navigator.of(context).pop(),
      ),
    );
  }

  static Future<void> showLocationPermission(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PermissionDialog(
        title: 'Location Permission Required',
        message:
            'Smart Pet Collar needs location permission to show your pet\'s position on the map.',
        icon: Icons.location_on,
        permissionName: 'Location',
        onAllow: () => Navigator.of(context).pop(),
        onDeny: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (onDeny != null)
          TextButton(
            onPressed: onDeny,
            child: const Text('Not Now'),
          ),
        ElevatedButton(
          onPressed: onAllow,
          child: Text('Allow $permissionName'),
        ),
      ],
    );
  }
}
