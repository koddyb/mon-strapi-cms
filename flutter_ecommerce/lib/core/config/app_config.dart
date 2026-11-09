class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'STRAPI_API_URL',
    defaultValue: 'http://127.0.0.1:1337/api',
  );
}
