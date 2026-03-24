import '../../models/user.dart';
import 'api_client.dart';

class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _client.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _client.post('/auth/logout');
    await _client.clearTokens();
  }

  Future<void> forgotPassword(String email) async {
    await _client.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  Future<Map<String, dynamic>> oauthGoogle(String idToken) async {
    final response = await _client.post(
      '/auth/oauth/google',
      data: {'idToken': idToken},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> oauthApple({
    required String identityToken,
    required String authorizationCode,
  }) async {
    final response = await _client.post(
      '/auth/oauth/apple',
      data: {
        'identityToken': identityToken,
        'authorizationCode': authorizationCode,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<User> getProfile() async {
    final response = await _client.get('/user/profile');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final response = await _client.patch('/user/profile', data: updates);
    return User.fromJson(response.data as Map<String, dynamic>);
  }
}
