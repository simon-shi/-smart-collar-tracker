import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../models/track_point.dart';
import '../services/api/api_client.dart';
import '../services/api/location_api.dart';
import '../services/ble/ble_service.dart';
import '../services/ble/ble_data_parser.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../config/ble_config.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';
import 'device_provider.dart';
import 'pet_provider.dart';

final locationApiProvider = Provider<LocationApi>(
  (ref) => LocationApi(ref.watch(apiClientProvider)),
);

final wsServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

class LocationNotifier extends StateNotifier<AsyncValue<PetLocation?>> {
  final LocationApi _locationApi;
  final BleService _bleService;
  final WebSocketService _wsService;
  StreamSubscription? _bleLocationSub;
  StreamSubscription? _wsLocationSub;
  final String? _petId;

  LocationNotifier(
    this._locationApi,
    this._bleService,
    this._wsService,
    this._petId,
  ) : super(const AsyncValue.loading()) {
    if (_petId != null) {
      _loadLatestLocation();
      _subscribeToBlE();
      _subscribeToWebSocket();
    }
  }

  Future<void> _loadLatestLocation() async {
    try {
      if (_petId == null) return;
      final location = await _locationApi.getLatestLocation(_petId!);
      state = AsyncValue.data(location);
    } catch (e, st) {
      AppLogger.error('Load latest location failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeToBlE() {
    _bleLocationSub?.cancel();
    _bleService.subscribeToCharacteristic(
      BleConfig.locationCharUuid,
    ).then((stream) {
      if (stream == null || _petId == null) return;
      _bleLocationSub = stream.listen((data) {
        final location = BleDataParser.parseLocation(data, petId: _petId!);
        if (location != null) {
          state = AsyncValue.data(location);
          StorageService.saveLocation(_petId!, location.toJson());
        }
      });
    });
  }

  void _subscribeToWebSocket() {
    _wsLocationSub?.cancel();
    _wsLocationSub = _wsService.locationStream.listen((location) {
      if (location.petId == _petId) {
        state = AsyncValue.data(location);
      }
    });
  }

  @override
  void dispose() {
    _bleLocationSub?.cancel();
    _wsLocationSub?.cancel();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider.family<LocationNotifier,
    AsyncValue<PetLocation?>, String?>(
  (ref, petId) => LocationNotifier(
    ref.watch(locationApiProvider),
    ref.watch(bleServiceProvider),
    ref.watch(wsServiceProvider),
    petId,
  ),
);

final selectedPetLocationProvider = Provider<AsyncValue<PetLocation?>>((ref) {
  final petId = ref.watch(selectedPetIdProvider);
  return ref.watch(locationProvider(petId));
});

// Location history
final locationHistoryProvider = FutureProvider.family<List<PetLocation>, String>(
  (ref, petId) async {
    final api = ref.watch(locationApiProvider);
    return api.getLocationHistory(
      petId,
      from: DateTime.now().subtract(const Duration(hours: 24)),
      to: DateTime.now(),
    );
  },
);

// Track replay
final trackReplayProvider = FutureProvider.family<List<TrackPoint>,
    ({String petId, DateTime from, DateTime to})>(
  (ref, params) async {
    final api = ref.watch(locationApiProvider);
    return api.getTrackReplay(
      params.petId,
      from: params.from,
      to: params.to,
    );
  },
);
