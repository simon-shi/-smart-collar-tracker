import '../../models/pet.dart';
import 'api_client.dart';

class PetApi {
  final ApiClient _client;

  PetApi(this._client);

  Future<List<Pet>> getPets() async {
    final response = await _client.get('/pets');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Pet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Pet> getPet(String id) async {
    final response = await _client.get('/pets/$id');
    return Pet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Pet> createPet(Map<String, dynamic> petData) async {
    final response = await _client.post('/pets', data: petData);
    return Pet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Pet> updatePet(String id, Map<String, dynamic> updates) async {
    final response = await _client.patch('/pets/$id', data: updates);
    return Pet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePet(String id) async {
    await _client.delete('/pets/$id');
  }

  Future<String> uploadPetPhoto(String petId, String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    final response = await _client.post(
      '/pets/$petId/photo',
      data: formData,
    );
    return response.data['photoUrl'] as String;
  }
}

// Re-export for convenience
export 'package:dio/dio.dart' show FormData, MultipartFile;
