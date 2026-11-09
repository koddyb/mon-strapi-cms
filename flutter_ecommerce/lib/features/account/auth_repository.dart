import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/strapi_api_client.dart';
import '../catalog/catalog_providers.dart';
import 'auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(strapiApiClientProvider));
});

class AuthRepository {
  const AuthRepository(this._client);

  final StrapiApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      'auth/local',
      body: {'identifier': email, 'password': password},
    );
    return _sessionFromResponse(response);
  }

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      'auth/local/register',
      body: {'username': username, 'email': email, 'password': password},
    );
    return _sessionFromResponse(response);
  }

  AuthSession _sessionFromResponse(Map<String, Object?> response) {
    final jwt = response['jwt'];
    final user = response['user'];
    if (jwt is! String || user is! Map<String, Object?>) {
      throw const ApiException(
        message: 'Strapi did not return a customer session.',
      );
    }
    final email = user['email'];
    final username = user['username'];
    if (email is! String || username is! String) {
      throw const ApiException(
        message: 'Strapi returned an invalid customer profile.',
      );
    }
    return AuthSession(jwt: jwt, email: email, username: username);
  }
}
