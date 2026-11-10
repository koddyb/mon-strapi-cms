import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tlveta/core/network/strapi_api_client.dart';
import 'package:tlveta/features/account/auth_session.dart';
import 'package:tlveta/features/account/profile_repository.dart';

void main() {
  test('loads the signed-in customer profile from Strapi', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/users/me');
      return http.Response(
        jsonEncode({
          'id': 37,
          'username': 'client-tlveta',
          'email': 'client@example.com',
          'firstName': 'Amina',
          'lastName': 'Diallo',
          'phoneNumber': '+33123456789',
          'avatarUrl': 'https://example.com/avatar.jpg',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ProfileRepository(
      StrapiApiClient(
        baseUri: Uri.parse('https://store.example.com/api'),
        httpClient: client,
        bearerToken: 'customer-jwt',
      ),
      const AuthSession(
        jwt: 'customer-jwt',
        userId: '37',
        email: 'client@example.com',
        username: 'client-tlveta',
      ),
    );

    final profile = await repository.getProfile();

    expect(profile.firstName, 'Amina');
    expect(profile.lastName, 'Diallo');
    expect(profile.phoneNumber, '+33123456789');
    expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
  });

  test('updates only the current customer profile fields', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/users/37');
      expect(
        jsonDecode(request.body),
        {
          'firstName': 'Amina',
          'lastName': 'Diallo',
          'phoneNumber': '+33123456789',
          'avatarUrl': 'https://example.com/avatar.jpg',
        },
      );
      return http.Response(
        jsonEncode({
          'id': 37,
          'username': 'client-tlveta',
          'email': 'client@example.com',
          'firstName': 'Amina',
          'lastName': 'Diallo',
          'phoneNumber': '+33123456789',
          'avatarUrl': 'https://example.com/avatar.jpg',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final repository = ProfileRepository(
      StrapiApiClient(
        baseUri: Uri.parse('https://store.example.com/api'),
        httpClient: client,
        bearerToken: 'customer-jwt',
      ),
      const AuthSession(
        jwt: 'customer-jwt',
        userId: '37',
        email: 'client@example.com',
        username: 'client-tlveta',
      ),
    );

    final profile = await repository.updateProfile(
      firstName: 'Amina',
      lastName: 'Diallo',
      phoneNumber: '+33123456789',
      avatarUrl: 'https://example.com/avatar.jpg',
    );

    expect(profile.email, 'client@example.com');
  });
}
