import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSession {
  const AuthSession({
    required this.jwt,
    required this.email,
    required this.username,
  });

  final String jwt;
  final String email;
  final String username;
}

class AuthSessionController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void signIn(AuthSession session) => state = session;

  void signOut() => state = null;
}

final authSessionProvider =
    NotifierProvider<AuthSessionController, AuthSession?>(
      AuthSessionController.new,
    );
