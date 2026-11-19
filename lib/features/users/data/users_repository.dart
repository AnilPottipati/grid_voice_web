import '../../../core/network/api_client.dart';
import '../domain/person.dart';

class UsersRepository {
  const UsersRepository(this._api);

  final ApiClient _api;

  Future<UsersResult> search({String query = '', String role = ''}) async {
    final json = await _api.getJson(
      '/api/live/users',
      query: {'q': query, 'role': role},
    );
    return UsersResult.fromJson(json);
  }
}
