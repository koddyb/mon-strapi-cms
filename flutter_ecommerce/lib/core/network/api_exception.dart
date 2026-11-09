class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  String get userMessage {
    return switch (statusCode) {
      401 =>
        'Identifiants incorrects ou session expirée. Connecte-toi à nouveau.',
      403 =>
        'Strapi a refusé l’accès au catalogue (403). '
            'Les permissions de lecture du rôle Public ne sont pas activées.',
      404 => 'Cette ressource n’existe pas sur le serveur.',
      int code when code >= 500 =>
        'Le serveur Strapi rencontre un problème. Réessaie plus tard.',
      _ => message,
    };
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
