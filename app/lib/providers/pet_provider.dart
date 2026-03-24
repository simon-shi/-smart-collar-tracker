import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pet.dart';
import '../services/api/api_client.dart';
import '../services/api/pet_api.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

final petApiProvider = Provider<PetApi>(
  (ref) => PetApi(ref.watch(apiClientProvider)),
);

class PetListNotifier extends StateNotifier<AsyncValue<List<Pet>>> {
  final PetApi _petApi;

  PetListNotifier(this._petApi) : super(const AsyncValue.loading()) {
    loadPets();
  }

  Future<void> loadPets() async {
    state = const AsyncValue.loading();
    try {
      final pets = await _petApi.getPets();
      state = AsyncValue.data(pets);
      // Cache pets locally
      await StorageService.cacheList(
        'pets',
        pets.map((p) => p.toJson()).toList(),
      );
    } catch (e, st) {
      AppLogger.error('Load pets failed: $e');
      // Try loading from cache
      final cached = StorageService.getCachedList('pets');
      if (cached != null) {
        final pets = cached.map(Pet.fromJson).toList();
        state = AsyncValue.data(pets);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<Pet?> createPet(Map<String, dynamic> petData) async {
    try {
      final pet = await _petApi.createPet(petData);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, pet]);
      return pet;
    } catch (e) {
      AppLogger.error('Create pet failed: $e');
      return null;
    }
  }

  Future<Pet?> updatePet(String id, Map<String, dynamic> updates) async {
    try {
      final updated = await _petApi.updatePet(id, updates);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((p) => p.id == id ? updated : p).toList(),
      );
      return updated;
    } catch (e) {
      AppLogger.error('Update pet failed: $e');
      return null;
    }
  }

  Future<bool> deletePet(String id) async {
    try {
      await _petApi.deletePet(id);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(current.where((p) => p.id != id).toList());
      return true;
    } catch (e) {
      AppLogger.error('Delete pet failed: $e');
      return false;
    }
  }
}

final petListProvider =
    StateNotifierProvider<PetListNotifier, AsyncValue<List<Pet>>>(
  (ref) => PetListNotifier(ref.watch(petApiProvider)),
);

// Currently selected/active pet
final selectedPetIdProvider = StateProvider<String?>((ref) {
  final pets = ref.watch(petListProvider).valueOrNull;
  if (pets == null || pets.isEmpty) return null;
  return pets.first.id;
});

final selectedPetProvider = Provider<Pet?>((ref) {
  final petId = ref.watch(selectedPetIdProvider);
  final pets = ref.watch(petListProvider).valueOrNull;
  if (petId == null || pets == null) return null;
  try {
    return pets.firstWhere((p) => p.id == petId);
  } catch (_) {
    return pets.isNotEmpty ? pets.first : null;
  }
});
