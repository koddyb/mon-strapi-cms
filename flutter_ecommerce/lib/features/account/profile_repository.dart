import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/strapi_api_client.dart';
import '../catalog/catalog_providers.dart';
import 'auth_session.dart';

final customerProfileProvider = FutureProvider<CustomerProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(strapiApiClientProvider),
    ref.watch(authSessionProvider),
  );
});

class ProfileRepository {
  const ProfileRepository(this._client, this._session);

  final StrapiApiClient _client;
  final AuthSession? _session;

  Future<CustomerProfile> getProfile() async {
    final response = await _client.get('users/me');
    return CustomerProfile.fromJson(_profileData(response));
  }

  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String avatarUrl,
  }) async {
    if (_session == null) {
      throw const ApiException(
        message: 'Connectez-vous pour modifier le profil.',
      );
    }
    final response = await _client.put(
      'client/profil',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
      },
    );
    return CustomerProfile.fromJson(_profileData(response));
  }

  Map<String, Object?> _profileData(Map<String, Object?> response) {
    final data = response['data'] ?? response;
    if (data is! Map<String, Object?>) {
      throw const ApiException(message: 'Strapi returned an invalid profile.');
    }
    return data;
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.avatarUrl,
  });

  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String avatarUrl;

  factory CustomerProfile.fromJson(Map<String, Object?> json) {
    final username = json['username'];
    final email = json['email'];
    final firstName = json['firstName'];
    final lastName = json['lastName'];
    final phoneNumber = json['phoneNumber'];
    final avatarUrl = json['avatarUrl'];
    if (username is! String ||
        email is! String ||
        (firstName != null && firstName is! String) ||
        (lastName != null && lastName is! String) ||
        (phoneNumber != null && phoneNumber is! String) ||
        (avatarUrl != null && avatarUrl is! String)) {
      throw const ApiException(message: 'Strapi returned an invalid profile.');
    }
    return CustomerProfile(
      username: username,
      email: email,
      firstName: firstName as String? ?? '',
      lastName: lastName as String? ?? '',
      phoneNumber: phoneNumber as String? ?? '',
      avatarUrl: avatarUrl as String? ?? '',
    );
  }
}
