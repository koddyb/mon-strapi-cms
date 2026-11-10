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

final orderTrackingProvider =
    FutureProvider.family<CustomerOrder, String>((ref, documentId) {
      return ref.watch(orderRepositoryProvider).getOrder(documentId);
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
    required this.trackingStatus,
    this.trackingCarrier,
    this.trackingNumber,
    this.trackingUpdatedAt,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.trackingEvents = const [],
  });

  final String documentId;
  final String status;
  final double total;
  final DateTime createdAt;
  final String trackingStatus;
  final String? trackingCarrier;
  final String? trackingNumber;
  final DateTime? trackingUpdatedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final List<OrderTrackingEvent> trackingEvents;

  factory CustomerOrder.fromJson(Map<String, Object?> json) {
    final documentId = json['documentId'];
    final status = json['status'];
    final total = json['total'];
    final createdAt = json['createdAt'];
    final trackingStatus = json['trackingStatus'];
    final trackingCarrier = json['trackingCarrier'];
    final trackingNumber = json['trackingNumber'];
    final trackingEvents = json['trackingEvents'];
    if (documentId is! String ||
        status is! String ||
        total is! num ||
        createdAt is! String ||
        (trackingStatus != null && trackingStatus is! String) ||
        (trackingCarrier != null && trackingCarrier is! String) ||
        (trackingNumber != null && trackingNumber is! String) ||
        (trackingEvents != null && trackingEvents is! List<Object?>)) {
      throw const FormatException('Invalid Strapi order.');
    }
    final eventData = trackingEvents is List<Object?>
        ? trackingEvents
        : const <Object?>[];
    final events = eventData
        .map((event) {
          if (event is! Map<String, Object?>) {
            throw const FormatException('Invalid Strapi tracking event.');
          }
          return OrderTrackingEvent.fromJson(event);
        })
        .toList(growable: false);
    return CustomerOrder(
      documentId: documentId,
      status: status,
      total: total.toDouble(),
      createdAt: DateTime.parse(createdAt),
      trackingStatus: trackingStatus is String
          ? trackingStatus
          : status == 'paid'
          ? 'payment_confirmed'
          : 'awaiting_payment',
      trackingCarrier: trackingCarrier is String ? trackingCarrier : null,
      trackingNumber: trackingNumber is String ? trackingNumber : null,
      trackingUpdatedAt: _optionalDate(json['trackingUpdatedAt']),
      paidAt: _optionalDate(json['paidAt']),
      shippedAt: _optionalDate(json['shippedAt']),
      deliveredAt: _optionalDate(json['deliveredAt']),
      trackingEvents: events,
    );
  }
}

class OrderTrackingEvent {
  const OrderTrackingEvent({required this.status, required this.happenedAt});

  final String status;
  final DateTime happenedAt;

  factory OrderTrackingEvent.fromJson(Map<String, Object?> json) {
    final status = json['status'];
    final happenedAt = json['happenedAt'];
    if (status is! String || happenedAt is! String) {
      throw const FormatException('Invalid Strapi tracking event.');
    }
    return OrderTrackingEvent(
      status: status,
      happenedAt: DateTime.parse(happenedAt),
    );
  }
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid Strapi date.');
  return DateTime.parse(value);
}
