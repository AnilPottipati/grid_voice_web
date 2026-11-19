import '../../../core/network/api_client.dart';
import '../domain/auth_state.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthUser> login(String login, String password) async {
    final json = await _api.postJson('/api/auth/login', {
      'login': login,
      'password': password,
    });
    return AuthUser.fromJson(json);
  }

  /// The signed-in user from the session cookie, or null when there is none.
  Future<AuthUser?> me() async {
    try {
      return AuthUser.fromJson(await _api.getJson('/api/auth/me'));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.postJson('/api/auth/logout', {});
    } on ApiException {
      // Signing out locally is enough.
    }
  }
}
