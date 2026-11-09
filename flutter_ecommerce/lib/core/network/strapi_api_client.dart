import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class StrapiApiClient {
  StrapiApiClient({
    required this.baseUri,
    required this.httpClient,
    this.bearerToken,
    this.timeout = const Duration(seconds: 12),
  });

  final Uri baseUri;
  final http.Client httpClient;
  final String? bearerToken;
  final Duration timeout;

  Future<Map<String, Object?>> get(
    String resource, {
    Map<String, String> queryParameters = const {},
  }) async {
    return _request('GET', resource, queryParameters: queryParameters);
  }

  Future<Map<String, Object?>> post(String resource, {Object? body}) async {
    return _request('POST', resource, body: body);
  }

  Future<Map<String, Object?>> put(String resource, {Object? body}) async {
    return _request('PUT', resource, body: body);
  }

  Future<Map<String, Object?>> delete(String resource) async {
    return _request('DELETE', resource);
  }

  Future<Map<String, Object?>> _request(
    String method,
    String resource, {
    Map<String, String> queryParameters = const {},
    Object? body,
  }) async {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final uri = baseUri.replace(
      path: '$basePath$resource',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
    };
    late final http.Response response;
    try {
      final request = switch (method) {
        'GET' => httpClient.get(uri, headers: headers),
        'POST' => httpClient.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'PUT' => httpClient.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'DELETE' => httpClient.delete(uri, headers: headers),
        _ => throw ArgumentError.value(
          method,
          'method',
          'Unsupported HTTP method',
        ),
      };
      response = await request.timeout(timeout);
    } on TimeoutException {
      throw const ApiException(message: 'The request to Strapi timed out.');
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the local Strapi server.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Strapi returned an invalid JSON response.',
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Strapi returned an unexpected response.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message =
          error is Map<String, Object?> && error['message'] is String
          ? error['message']! as String
          : 'Strapi request failed (${response.statusCode}).';
      throw ApiException(statusCode: response.statusCode, message: message);
    }

    return decoded;
  }

  Uri resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    return baseUri.resolve(path);
  }
}
