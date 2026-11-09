import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/strapi_api_client.dart';
import '../account/auth_session.dart';
import '../categories/category.dart';
import '../products/product.dart';
import 'catalog_repository.dart';

final strapiApiClientProvider = Provider<StrapiApiClient>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close);
  return StrapiApiClient(
    baseUri: Uri.parse(AppConfig.apiBaseUrl),
    httpClient: httpClient,
    bearerToken: ref.watch(authSessionProvider)?.jwt,
  );
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(strapiApiClientProvider));
});

final productCategoriesProvider = FutureProvider<List<ProductCategory>>((ref) {
  return ref.watch(catalogRepositoryProvider).getCategories();
});

typedef CatalogQuery = ({String? categoryId, String search, String sort});

final catalogProductsProvider =
    FutureProvider.family<List<Product>, CatalogQuery>((ref, query) {
      return ref
          .watch(catalogRepositoryProvider)
          .getProducts(
            categoryId: query.categoryId,
            search: query.search,
            sort: query.sort,
          );
    });

final productDetailProvider = FutureProvider.family<Product, String>((
  ref,
  documentId,
) {
  return ref.watch(catalogRepositoryProvider).getProduct(documentId);
});
