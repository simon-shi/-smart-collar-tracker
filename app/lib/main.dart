import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive local database
  await Hive.initFlutter();
  await StorageService.initialize();

  // Initialize notifications
  await NotificationService.initialize();

  AppLogger.info('Smart Collar Tracker starting...');

  runApp(
    const ProviderScope(
      child: SmartCollarApp(),
    ),
  );
}
