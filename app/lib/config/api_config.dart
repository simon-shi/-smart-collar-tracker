import 'app_config.dart';

class ApiConfig {
  static String get baseUrl => AppConfig.baseUrl;

  // Auth
  static String get login => '/auth/login';
  static String get register => '/auth/register';
  static String get refreshToken => '/auth/refresh';
  static String get logout => '/auth/logout';
  static String get forgotPassword => '/auth/forgot-password';
  static String get resetPassword => '/auth/reset-password';
  static String get oauthGoogle => '/auth/oauth/google';
  static String get oauthApple => '/auth/oauth/apple';

  // User
  static String get userProfile => '/user/profile';
  static String get updateProfile => '/user/profile';
  static String get deleteAccount => '/user/account';
  static String get exportData => '/user/data/export';

  // Pet
  static String get pets => '/pets';
  static String petById(String id) => '/pets/$id';
  static String petPhoto(String id) => '/pets/$id/photo';

  // Device
  static String get devices => '/devices';
  static String deviceById(String id) => '/devices/$id';
  static String deviceFirmware(String id) => '/devices/$id/firmware';
  static String deviceSettings(String id) => '/devices/$id/settings';

  // Location
  static String locationHistory(String petId) => '/pets/$petId/locations';
  static String latestLocation(String petId) => '/pets/$petId/locations/latest';
  static String trackReplay(String petId) => '/pets/$petId/locations/track';

  // Activity
  static String activityData(String petId) => '/pets/$petId/activity';
  static String activitySummary(String petId) => '/pets/$petId/activity/summary';

  // Health
  static String healthReports(String petId) => '/pets/$petId/health/reports';
  static String healthAnomalies(String petId) => '/pets/$petId/health/anomalies';

  // Geofence
  static String geofences(String petId) => '/pets/$petId/geofences';
  static String geofenceById(String petId, String gfId) =>
      '/pets/$petId/geofences/$gfId';
  static String geofenceHistory(String petId, String gfId) =>
      '/pets/$petId/geofences/$gfId/history';

  // Notifications
  static String get notifications => '/notifications';
  static String get notificationSettings => '/notifications/settings';
  static String get fcmToken => '/notifications/fcm-token';
}
