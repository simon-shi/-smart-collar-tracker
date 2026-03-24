import '../../models/device.dart';
import 'api_client.dart';

class DeviceApi {
  final ApiClient _client;

  DeviceApi(this._client);

  Future<List<Device>> getDevices() async {
    final response = await _client.get('/devices');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Device> getDevice(String id) async {
    final response = await _client.get('/devices/$id');
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Device> registerDevice(Map<String, dynamic> deviceData) async {
    final response = await _client.post('/devices', data: deviceData);
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Device> updateDeviceSettings(
    String id,
    Map<String, dynamic> settings,
  ) async {
    final response = await _client.patch('/devices/$id/settings', data: settings);
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDevice(String id) async {
    await _client.delete('/devices/$id');
  }

  Future<Map<String, dynamic>> getLatestFirmware(String deviceId) async {
    final response = await _client.get('/devices/$deviceId/firmware/latest');
    return response.data as Map<String, dynamic>;
  }

  Future<String> getFirmwareDownloadUrl(
    String deviceId,
    String version,
  ) async {
    final response = await _client.get(
      '/devices/$deviceId/firmware/$version/download-url',
    );
    return response.data['url'] as String;
  }
}
