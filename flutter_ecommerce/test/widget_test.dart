import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tlveta/core/network/api_exception.dart';
import 'package:tlveta/core/network/strapi_api_client.dart';
import 'package:tlveta/features/catalog/catalog_page.dart';
import 'package:tlveta/features/catalog/catalog_providers.dart';
import 'package:tlveta/features/catalog/catalog_repository.dart';
import 'package:tlveta/features/products/product.dart';

void main() {
  test('parses a Strapi v5 product and resolves its media URL', () {
    final product = Product.fromJson(
      {
        'documentId': 'product-123',
        'title': 'Casque Sans Fil ANC Studio Pro',
        'slug': 'casque-sans-fil-anc-studio-pro',
        'description': 'Réduction active du bruit',
        'price': 2.54,
        'image': {'url': '/uploads/casque.jpg'},
        'images': [
          {'url': '/uploads/casque.jpg'},
          {'url': '/uploads/casque-detail.jpg'},
        ],
        'category': {'documentId': 'category-456', 'name': 'Audio & Casques'},
      },
      resolveMediaUrl: (path) =>
          Uri.parse('http://127.0.0.1:1350').resolve(path),
    );

    expect(product.documentId, 'product-123');
    expect(product.title, 'Casque Sans Fil ANC Studio Pro');
    expect(product.imageUrl, 'http://127.0.0.1:1350/uploads/casque.jpg');
    expect(product.imageUrls, [
      'http://127.0.0.1:1350/uploads/casque.jpg',
      'http://127.0.0.1:1350/uploads/casque-detail.jpg',
    ]);
    expect(product.category?.name, 'Audio & Casques');
    expect(product.price, 2.54);
  });

  test('preserves Strapi filter parameters in the real request URI', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/produits');
      expect(
        request.url.queryParameters[r'filters[category][documentId][$eq]'],
        'category-456',
      );
      expect(request.url.queryParameters['populate[image]'], 'true');
      expect(request.url.queryParameters['populate[images]'], 'true');
      expect(request.url.queryParameters['populate[category]'], 'true');
      expect(request.url.queryParameters['populate[panier]'], isNull);
      return http.Response(
        jsonEncode({
          'data': [
            {
              'documentId': 'product-123',
              'title': 'Casque Sans Fil ANC Studio Pro',
              'slug': 'casque-sans-fil-anc-studio-pro',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final apiClient = StrapiApiClient(
      baseUri: Uri.parse('http://localhost:1350/api'),
      httpClient: client,
    );
    final repository = CatalogRepository(apiClient);

    final products = await repository.getProducts(
      categoryId: 'category-456',
      search: '',
    );

    expect(products, hasLength(1));
    expect(products.single.title, 'Casque Sans Fil ANC Studio Pro');
  });

  test('surfaces a Strapi 403 as a typed API error', () async {
    final apiClient = StrapiApiClient(
      baseUri: Uri.parse('http://localhost:1350/api'),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {'status': 403, 'message': 'Forbidden'},
          }),
          403,
        ),
      ),
    );

    await expectLater(
      apiClient.get('produits'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.userMessage,
              'userMessage',
              contains('permissions de lecture'),
            ),
      ),
    );
  });

  test('sends the customer JWT as a bearer token', () async {
    final client = MockClient((request) async {
      expect(
        request.headers['authorization'],
        ['Bearer', 'customer-jwt'].join(' '),
      );
      return http.Response(
        jsonEncode({'data': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final apiClient = StrapiApiClient(
      baseUri: Uri.parse('http://localhost:1350/api'),
      httpClient: client,
      bearerToken: 'customer-jwt',
    );

    await apiClient.get('mon-panier');
  });

  testWidgets('shows the real backend permission error without fake products', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productCategoriesProvider.overrideWith((ref) async => []),
          catalogProductsProvider.overrideWith((ref, query) async {
            throw const ApiException(statusCode: 403, message: 'Forbidden');
          }),
        ],
        child: const MaterialApp(home: CatalogPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Accès au catalogue refusé'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Accès au catalogue refusé'), findsOneWidget);
    expect(
      find.textContaining('Aucune donnée de démonstration n’est affichée.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
