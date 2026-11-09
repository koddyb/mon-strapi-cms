import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/strapi_api_client.dart';
import '../catalog/catalog_providers.dart';
import '../products/product.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(strapiApiClientProvider));
});

final customerCartProvider = FutureProvider<CustomerCart>((ref) {
  return ref.watch(cartRepositoryProvider).getCart();
});

class CustomerCart {
  const CustomerCart({required this.items});

  const CustomerCart.empty() : items = const [];

  final List<CartItem> items;

  double get subtotal => items.fold(
    0,
    (total, item) => total + (item.product.price ?? 0) * item.quantity,
  );

  bool get hasPrices => items.every((item) => item.product.price != null);
}

class CartItem {
  const CartItem({
    required this.documentId,
    required this.quantity,
    required this.product,
  });

  final String documentId;
  final int quantity;
  final Product product;

  factory CartItem.fromJson(
    Map<String, Object?> json, {
    required Uri Function(String path) resolveMediaUrl,
  }) {
    final documentId = json['documentId'];
    final quantity = json['quantity'];
    final product = json['product'];
    if (documentId is! String ||
        quantity is! int ||
        product is! Map<String, Object?>) {
      throw const FormatException('Strapi returned an invalid cart line.');
    }
    return CartItem(
      documentId: documentId,
      quantity: quantity,
      product: Product.fromJson(product, resolveMediaUrl: resolveMediaUrl),
    );
  }
}

class CartRepository {
  const CartRepository(this._client);

  final StrapiApiClient _client;

  Future<CustomerCart> getCart() async {
    final response = await _client.get('mon-panier');
    final data = response['data'];
    if (data == null) return const CustomerCart.empty();
    if (data is! Map<String, Object?> || data['items'] is! List<Object?>) {
      throw const ApiException(message: 'Strapi returned an invalid cart.');
    }
    final items = data['items']! as List<Object?>;
    return CustomerCart(
      items: items
          .map((item) {
            if (item is! Map<String, Object?>) {
              throw const ApiException(
                message: 'Strapi returned an invalid cart line.',
              );
            }
            return CartItem.fromJson(
              item,
              resolveMediaUrl: _client.resolveMediaUrl,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> addProduct(String documentId, {int quantity = 1}) async {
    await _client.post(
      'mon-panier/lignes',
      body: {'productDocumentId': documentId, 'quantity': quantity},
    );
  }

  Future<void> updateQuantity(String lineId, int quantity) async {
    await _client.put(
      'mon-panier/lignes/$lineId',
      body: {'quantity': quantity},
    );
  }

  Future<void> removeLine(String lineId) async {
    await _client.delete('mon-panier/lignes/$lineId');
  }

  Future<CheckoutOrder> createCheckoutOrder() async {
    final response = await _client.post('checkout/commandes');
    final data = response['data'];
    if (data is! Map<String, Object?> ||
        data['orderId'] is! String ||
        data['total'] is! num) {
      throw const ApiException(
        message: 'Strapi did not return a valid checkout order.',
      );
    }
    return CheckoutOrder(
      documentId: data['orderId']! as String,
      total: (data['total']! as num).toDouble(),
    );
  }
}

class CheckoutOrder {
  const CheckoutOrder({required this.documentId, required this.total});

  final String documentId;
  final double total;
}
