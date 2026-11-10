import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSession {
  const AuthSession({
    required this.jwt,
    required this.email,
    required this.username,
    this.firstName = '',
    this.lastName = '',
    this.avatarUrl = '',
  });

  final String jwt;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String avatarUrl;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }
}

class AuthSessionController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void signIn(AuthSession session) => state = session;

  void updateProfile({
    required String firstName,
    required String lastName,
    required String avatarUrl,
  }) {
    final session = state;
    if (session == null) return;
    state = AuthSession(
      jwt: session.jwt,
      email: session.email,
      username: session.username,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
    );
  }

  void signOut() => state = null;
}

final authSessionProvider =
    NotifierProvider<AuthSessionController, AuthSession?>(
      AuthSessionController.new,
    );
