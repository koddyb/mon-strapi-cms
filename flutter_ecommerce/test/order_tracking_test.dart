import 'package:flutter_test/flutter_test.dart';
import 'package:tlveta/features/account/order_repository.dart';

void main() {
  test('parses persisted tracking milestones and carrier details', () {
    final order = CustomerOrder.fromJson({
      'documentId': 'order-123',
      'status': 'paid',
      'total': 24.50,
      'createdAt': '2026-01-10T09:00:00.000Z',
      'trackingStatus': 'shipped',
      'trackingCarrier': 'Colissimo',
      'trackingNumber': 'AB123456789FR',
      'trackingUpdatedAt': '2026-01-12T10:00:00.000Z',
      'paidAt': '2026-01-10T09:05:00.000Z',
      'shippedAt': '2026-01-12T10:00:00.000Z',
      'trackingEvents': [
        {
          'status': 'awaiting_payment',
          'happenedAt': '2026-01-10T09:00:00.000Z',
        },
        {
          'status': 'payment_confirmed',
          'happenedAt': '2026-01-10T09:05:00.000Z',
        },
        {'status': 'shipped', 'happenedAt': '2026-01-12T10:00:00.000Z'},
      ],
    });

    expect(order.trackingStatus, 'shipped');
    expect(order.trackingCarrier, 'Colissimo');
    expect(order.trackingNumber, 'AB123456789FR');
    expect(order.trackingEvents, hasLength(3));
    expect(order.trackingEvents.last.status, 'shipped');
    expect(order.shippedAt, DateTime.parse('2026-01-12T10:00:00.000Z'));
  });

  test('uses the payment state for older orders without tracking fields', () {
    final order = CustomerOrder.fromJson({
      'documentId': 'order-older',
      'status': 'paid',
      'total': 9,
      'createdAt': '2026-01-10T09:00:00.000Z',
    });

    expect(order.trackingStatus, 'payment_confirmed');
    expect(order.trackingEvents, isEmpty);
    expect(order.trackingCarrier, isNull);
  });

  test('rejects malformed tracking events instead of hiding them', () {
    expect(
      () => CustomerOrder.fromJson({
        'documentId': 'order-invalid',
        'status': 'paid',
        'total': 9,
        'createdAt': '2026-01-10T09:00:00.000Z',
        'trackingEvents': [
          {'status': 'shipped'},
        ],
      }),
      throwsFormatException,
    );
  });
}
