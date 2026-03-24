import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../utils/logger.dart';

class StorageService {
  static const String _settingsBox = 'settings';
  static const String _cacheBox = 'cache';
  static const String _locationsBox = 'locations';
  static const String _activityBox = 'activity';

  static Future<void> initialize() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_cacheBox);
    await Hive.openBox(_locationsBox);
    await Hive.openBox(_activityBox);
    AppLogger.info('StorageService initialized');
  }

  // Settings
  static Box get _settings => Hive.box(_settingsBox);
  static Box get _cache => Hive.box(_cacheBox);
  static Box get _locations => Hive.box(_locationsBox);
  static Box get _activity => Hive.box(_activityBox);

  static Future<void> saveSetting(String key, dynamic value) async {
    await _settings.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings.get(key, defaultValue: defaultValue) as T?;
  }

  static Future<void> deleteSetting(String key) async {
    await _settings.delete(key);
  }

  // Cache
  static Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await _cache.put(key, json.encode(data));
  }

  static Map<String, dynamic>? getCachedData(String key) {
    final raw = _cache.get(key) as String?;
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Cache decode error: $e');
      return null;
    }
  }

  static Future<void> cacheList(String key, List<Map<String, dynamic>> items) async {
    await _cache.put(key, json.encode(items));
  }

  static List<Map<String, dynamic>>? getCachedList(String key) {
    final raw = _cache.get(key) as String?;
    if (raw == null) return null;
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      AppLogger.error('Cache list decode error: $e');
      return null;
    }
  }

  static Future<void> clearCache() async {
    await _cache.clear();
  }

  // Location cache (ring buffer, max 1000 per pet)
  static Future<void> saveLocation(
    String petId,
    Map<String, dynamic> location,
  ) async {
    final key = 'pet_$petId';
    final existing = getCachedLocations(petId);
    existing.add(location);

    // Keep only last 1000 locations
    final trimmed =
        existing.length > 1000 ? existing.sublist(existing.length - 1000) : existing;

    await _locations.put(key, json.encode(trimmed));
  }

  static List<Map<String, dynamic>> getCachedLocations(String petId) {
    final key = 'pet_$petId';
    final raw = _locations.get(key) as String?;
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearLocations(String petId) async {
    await _locations.delete('pet_$petId');
  }

  // Activity cache
  static Future<void> saveActivity(
    String petId,
    String date,
    Map<String, dynamic> data,
  ) async {
    await _activity.put('${petId}_$date', json.encode(data));
  }

  static Map<String, dynamic>? getActivity(String petId, String date) {
    final raw = _activity.get('${petId}_$date') as String?;
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    await Future.wait([
      _settings.clear(),
      _cache.clear(),
      _locations.clear(),
      _activity.clear(),
    ]);
  }
}
