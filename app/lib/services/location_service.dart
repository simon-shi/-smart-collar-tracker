import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/location.dart';
import '../utils/logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<PetLocation>.broadcast();

  Stream<PetLocation> get locationStream => _locationController.stream;

  /// Request location permissions
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.warn('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.warn('Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.warn('Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Get current device position
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      AppLogger.error('Get current position error: $e');
      return null;
    }
  }

  /// Start continuous location updates
  Future<void> startLocationUpdates({
    String petId = 'device',
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        final location = PetLocation(
          id: 'device_${DateTime.now().millisecondsSinceEpoch}',
          petId: petId,
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
          source: 'phone_gps',
          timestamp: position.timestamp,
        );
        _locationController.add(location);
      },
      onError: (Object e) => AppLogger.error('Location stream error: $e'),
    );
  }

  Future<void> stopLocationUpdates() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}
