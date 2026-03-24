import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'smart_collar_alerts',
    'Smart Collar Alerts',
    description: 'Notifications from your pet collar',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    AppLogger.info('NotificationService initialized');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    AppLogger.debug('Notification tapped: ${response.payload}');
    // Navigate based on payload - handled by router
  }

  static Future<void> showGeofenceAlert({
    required String petName,
    required String geofenceName,
    required String eventType, // 'enter' or 'exit'
  }) async {
    final title = eventType == 'enter'
        ? '$petName entered $geofenceName'
        : '$petName left $geofenceName';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      'Tap to view on map',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_collar_alerts',
          'Smart Collar Alerts',
          channelDescription: 'Notifications from your pet collar',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'geofence:$eventType',
    );
  }

  static Future<void> showBatteryAlert({
    required String deviceName,
    required int batteryLevel,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Low Battery Warning',
      '$deviceName battery is at $batteryLevel%',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_collar_alerts',
          'Smart Collar Alerts',
          channelDescription: 'Notifications from your pet collar',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'battery:low',
    );
  }

  static Future<void> showHealthAlert({
    required String petName,
    required String anomalyType,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Health Alert: $petName',
      'Unusual activity detected: $anomalyType',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_collar_alerts',
          'Smart Collar Alerts',
          channelDescription: 'Notifications from your pet collar',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'health:anomaly',
    );
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
