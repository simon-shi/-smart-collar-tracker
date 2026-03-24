class AppConstants {
  // App
  static const String appName = 'Smart Pet Collar';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  static const String locationsBox = 'locations';
  static const String activityBox = 'activity';

  // Step goals
  static const int defaultDogStepGoal = 8000;
  static const int defaultCatStepGoal = 3000;

  // Battery thresholds
  static const int batteryLowThreshold = 20;
  static const int batteryCriticalThreshold = 10;

  // Map defaults
  static const double defaultMapZoom = 15.0;
  static const double defaultMapZoomPet = 17.0;

  // Privacy
  static const String privacyPolicyUrl = 'https://smartcollar.io/privacy';
  static const String termsOfServiceUrl = 'https://smartcollar.io/terms';
  static const String ccpaOptOutUrl = 'https://smartcollar.io/ccpa/opt-out';

  // Support
  static const String supportEmail = 'support@smartcollar.io';
  static const String supportUrl = 'https://smartcollar.io/support';

  // Assets
  static const String dogPlaceholder = 'assets/images/dog_placeholder.png';
  static const String catPlaceholder = 'assets/images/cat_placeholder.png';
  static const String petMarkerAsset = 'assets/images/pet_marker.png';
  static const String splashAnimation = 'assets/animations/splash.json';
  static const String loadingAnimation = 'assets/animations/loading.json';
  static const String emptyAnimation = 'assets/animations/empty.json';
  static const String successAnimation = 'assets/animations/success.json';

  // Timeouts
  static const int apiTimeoutSeconds = 30;
  static const int bleConnectTimeoutSeconds = 15;
  static const int wsReconnectDelaySeconds = 5;

  // Pagination
  static const int defaultPageSize = 20;

  // DFU
  static const String dfuZipExtension = '.zip';
  static const String dfuBinExtension = '.bin';
}
