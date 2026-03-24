/// Environment configuration
enum Environment { dev, staging, prod }

class AppConfig {
  static Environment _env = Environment.dev;

  static void setEnvironment(Environment env) {
    _env = env;
  }

  static Environment get currentEnv => _env;

  static bool get isDev => _env == Environment.dev;
  static bool get isStaging => _env == Environment.staging;
  static bool get isProd => _env == Environment.prod;

  static String get appName {
    switch (_env) {
      case Environment.dev:
        return 'Smart Collar [DEV]';
      case Environment.staging:
        return 'Smart Collar [STAGING]';
      case Environment.prod:
        return 'Smart Collar';
    }
  }

  static String get baseUrl {
    switch (_env) {
      case Environment.dev:
        return 'https://api-dev.smartcollar.io/v1';
      case Environment.staging:
        return 'https://api-staging.smartcollar.io/v1';
      case Environment.prod:
        return 'https://api.smartcollar.io/v1';
    }
  }

  static String get wsUrl {
    switch (_env) {
      case Environment.dev:
        return 'wss://ws-dev.smartcollar.io/v1';
      case Environment.staging:
        return 'wss://ws-staging.smartcollar.io/v1';
      case Environment.prod:
        return 'wss://ws.smartcollar.io/v1';
    }
  }

  static int get connectTimeoutMs => 15000;
  static int get receiveTimeoutMs => 30000;
  static int get tokenRefreshLeadSeconds => 300;
}
