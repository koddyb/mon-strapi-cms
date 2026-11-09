import '../../core/network/api_exception.dart';
import '../../core/network/strapi_api_client.dart';
import '../categories/category.dart';
import '../products/product.dart';

class CatalogRepository {
  const CatalogRepository(this._client);

  final StrapiApiClient _client;

  Future<List<Product>> getProducts({
    String? categoryId,
    String search = '',
    String sort = 'title:asc',
  }) async {
    final filters = <String, String>{};
    if (categoryId != null) {
      filters['filters[category][documentId][\$eq]'] = categoryId;
    }
    if (search.trim().isNotEmpty) {
      filters['filters[title][\$containsi]'] = search.trim();
    }

    final response = await _client.get(
      'produits',
      queryParameters: {
        ...filters,
        'sort': sort,
        'pagination[page]': '1',
        'pagination[pageSize]': '24',
        'populate[image]': 'true',
        'populate[images]': 'true',
        'populate[category]': 'true',
      },
    );
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ApiException(
        message: 'Strapi returned an invalid product list.',
      );
    }

    return data
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const ApiException(
              message: 'Strapi returned an invalid product document.',
            );
          }
          return Product.fromJson(
            item,
            resolveMediaUrl: _client.resolveMediaUrl,
          );
        })
        .toList(growable: false);
  }

  Future<Product> getProduct(String documentId) async {
    final response = await _client.get(
      'produits/$documentId',
      queryParameters: const {
        'populate[image]': 'true',
        'populate[images]': 'true',
        'populate[category]': 'true',
      },
    );
    final data = response['data'];
    if (data is! Map<String, Object?>) {
      throw const ApiException(
        message: 'Strapi returned an invalid product document.',
      );
    }
    return Product.fromJson(data, resolveMediaUrl: _client.resolveMediaUrl);
  }

  Future<List<ProductCategory>> getCategories() async {
    final response = await _client.get(
      'categories',
      queryParameters: const {
        'sort': 'name:asc',
        'pagination[page]': '1',
        'pagination[pageSize]': '100',
      },
    );
    final data = response['data'];
    if (data is! List<Object?>) {
      throw const ApiException(
        message: 'Strapi returned an invalid category list.',
      );
    }

    return data
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const ApiException(
              message: 'Strapi returned an invalid category document.',
            );
          }
          try {
            return ProductCategory.fromJson(item);
          } on FormatException catch (error) {
            throw ApiException(message: error.message);
          }
        })
        .toList(growable: false);
  }
}
