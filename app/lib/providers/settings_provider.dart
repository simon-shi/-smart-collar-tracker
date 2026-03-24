import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String units; // 'metric' or 'imperial'
  final String language; // 'en' or 'zh'
  final bool notificationsEnabled;
  final bool geofenceAlertsEnabled;
  final bool healthAlertsEnabled;
  final bool batteryAlertsEnabled;
  final bool activityGoalEnabled;
  final bool privacyConsentGiven;
  final bool doNotSellData; // CCPA
  final bool analyticsEnabled;
  final bool crashReportingEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.units = 'metric',
    this.language = 'en',
    this.notificationsEnabled = true,
    this.geofenceAlertsEnabled = true,
    this.healthAlertsEnabled = true,
    this.batteryAlertsEnabled = true,
    this.activityGoalEnabled = true,
    this.privacyConsentGiven = false,
    this.doNotSellData = false,
    this.analyticsEnabled = true,
    this.crashReportingEnabled = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? units,
    String? language,
    bool? notificationsEnabled,
    bool? geofenceAlertsEnabled,
    bool? healthAlertsEnabled,
    bool? batteryAlertsEnabled,
    bool? activityGoalEnabled,
    bool? privacyConsentGiven,
    bool? doNotSellData,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      units: units ?? this.units,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      geofenceAlertsEnabled:
          geofenceAlertsEnabled ?? this.geofenceAlertsEnabled,
      healthAlertsEnabled: healthAlertsEnabled ?? this.healthAlertsEnabled,
      batteryAlertsEnabled: batteryAlertsEnabled ?? this.batteryAlertsEnabled,
      activityGoalEnabled: activityGoalEnabled ?? this.activityGoalEnabled,
      privacyConsentGiven: privacyConsentGiven ?? this.privacyConsentGiven,
      doNotSellData: doNotSellData ?? this.doNotSellData,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final themeStr = StorageService.getSetting<String>('themeMode') ?? 'system';
    state = AppSettings(
      themeMode: _parseThemeMode(themeStr),
      units: StorageService.getSetting<String>('units') ?? 'metric',
      language: StorageService.getSetting<String>('language') ?? 'en',
      notificationsEnabled:
          StorageService.getSetting<bool>('notificationsEnabled') ?? true,
      geofenceAlertsEnabled:
          StorageService.getSetting<bool>('geofenceAlertsEnabled') ?? true,
      healthAlertsEnabled:
          StorageService.getSetting<bool>('healthAlertsEnabled') ?? true,
      batteryAlertsEnabled:
          StorageService.getSetting<bool>('batteryAlertsEnabled') ?? true,
      activityGoalEnabled:
          StorageService.getSetting<bool>('activityGoalEnabled') ?? true,
      privacyConsentGiven:
          StorageService.getSetting<bool>('privacyConsentGiven') ?? false,
      doNotSellData:
          StorageService.getSetting<bool>('doNotSellData') ?? false,
      analyticsEnabled:
          StorageService.getSetting<bool>('analyticsEnabled') ?? true,
      crashReportingEnabled:
          StorageService.getSetting<bool>('crashReportingEnabled') ?? true,
    );
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await StorageService.saveSetting('themeMode', mode.name);
  }

  Future<void> setUnits(String units) async {
    state = state.copyWith(units: units);
    await StorageService.saveSetting('units', units);
  }

  Future<void> setLanguage(String lang) async {
    state = state.copyWith(language: lang);
    await StorageService.saveSetting('language', lang);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await StorageService.saveSetting('notificationsEnabled', enabled);
  }

  Future<void> setGeofenceAlerts(bool enabled) async {
    state = state.copyWith(geofenceAlertsEnabled: enabled);
    await StorageService.saveSetting('geofenceAlertsEnabled', enabled);
  }

  Future<void> setHealthAlerts(bool enabled) async {
    state = state.copyWith(healthAlertsEnabled: enabled);
    await StorageService.saveSetting('healthAlertsEnabled', enabled);
  }

  Future<void> setPrivacyConsent(bool given) async {
    state = state.copyWith(privacyConsentGiven: given);
    await StorageService.saveSetting('privacyConsentGiven', given);
  }

  Future<void> setDoNotSellData(bool doNotSell) async {
    state = state.copyWith(doNotSellData: doNotSell);
    await StorageService.saveSetting('doNotSellData', doNotSell);
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    state = state.copyWith(analyticsEnabled: enabled);
    await StorageService.saveSetting('analyticsEnabled', enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsProvider).themeMode,
);

final unitsProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider).units,
);
