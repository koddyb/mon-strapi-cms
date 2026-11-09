import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/strapi_api_client.dart';
import '../catalog/catalog_providers.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(strapiApiClientProvider));
});

final customerOrdersProvider = FutureProvider<List<CustomerOrder>>((ref) async {
  final response = await ref
      .watch(strapiApiClientProvider)
      .get('commandes/miennes');
  final data = response['data'];
  if (data is! List<Object?>) {
    throw const ApiException(message: 'Strapi returned an invalid order list.');
  }
  return data
      .map((item) {
        if (item is! Map<String, Object?>) {
          throw const ApiException(
            message: 'Strapi returned an invalid order.',
          );
        }
        return CustomerOrder.fromJson(item);
      })
      .toList(growable: false);
});

class OrderRepository {
  const OrderRepository(this._client);

  final StrapiApiClient _client;

  Future<CustomerOrder> getOrder(String documentId) async {
    final response = await _client.get('mes-commandes/$documentId');
    final data = response['data'];
    if (data is! Map<String, Object?>) {
      throw const ApiException(message: 'Strapi returned an invalid order.');
    }
    return CustomerOrder.fromJson(data);
  }

  Future<DateTime> startPaymentSimulation(String documentId) async {
    final response = await _client.post('commandes/$documentId/simulation');
    final data = response['data'];
    if (data is! Map<String, Object?> || data['readyAt'] is! String) {
      throw const ApiException(
        message: 'Strapi returned an invalid payment simulation.',
      );
    }
    return DateTime.parse(data['readyAt']! as String);
  }

  Future<void> confirmPayment(String documentId) async {
    final response = await _client.post(
      'commandes/$documentId/confirmer-paiement',
    );
    final data = response['data'];
    if (data is! Map<String, Object?> || data['status'] != 'paid') {
      throw const ApiException(
        message: 'Strapi did not confirm the simulated payment.',
      );
    }
  }

  Future<void> saveShippingAddress(
    String documentId, {
    required Map<String, String> address,
  }) async {
    await _client.put(
      'commandes/$documentId/adresse-livraison',
      body: address,
    );
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.documentId,
    required this.status,
    required this.total,
    required this.createdAt,
  });

  final String documentId;
  final String status;
  final double total;
  final DateTime createdAt;

  factory CustomerOrder.fromJson(Map<String, Object?> json) {
    final documentId = json['documentId'];
    final status = json['status'];
    final total = json['total'];
    final createdAt = json['createdAt'];
    if (documentId is! String ||
        status is! String ||
        total is! num ||
        createdAt is! String) {
      throw const FormatException('Invalid Strapi order.');
    }
    return CustomerOrder(
      documentId: documentId,
      status: status,
      total: total.toDouble(),
      createdAt: DateTime.parse(createdAt),
    );
  }
}
