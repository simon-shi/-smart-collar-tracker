import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import '../services/api/api_client.dart';
import '../services/api/auth_api.dart';
import '../utils/logger.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _authApi;
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthNotifier(this._authApi, this._apiClient)
      : super(const AuthState(status: AuthStatus.initial)) {
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final token = await _apiClient.getAccessToken();
    if (token != null) {
      try {
        final user = await _authApi.getProfile();
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } catch (e) {
        AppLogger.error('Token validation failed: $e');
        await _apiClient.clearTokens();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final data = await _authApi.login(email: email, password: password);
      await _apiClient.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      AppLogger.error('Login failed: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final data = await _authApi.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _apiClient.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      AppLogger.error('Register failed: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle(String idToken) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final data = await _authApi.oauthGoogle(idToken);
      await _apiClient.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      AppLogger.error('Google login failed: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (e) {
      AppLogger.error('Logout API error: $e');
    }
    await _apiClient.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _authApi.getProfile();
      state = state.copyWith(user: user);
    } catch (e) {
      AppLogger.error('Refresh profile failed: $e');
    }
  }

  String _parseError(Object e) {
    return e.toString().replaceAll('Exception: ', '');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(
    ref.watch(authApiProvider),
    ref.watch(apiClientProvider),
  ),
);

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authProvider).user,
);
