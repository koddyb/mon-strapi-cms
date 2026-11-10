import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import 'auth_session.dart';
import 'order_repository.dart';

class OrderTrackingPage extends ConsumerWidget {
  const OrderTrackingPage({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authSessionProvider) == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Suivi de commande')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/compte'),
            child: const Text('Connectez-vous pour suivre cette commande'),
          ),
        ),
      );
    }

    final order = ref.watch(orderTrackingProvider(documentId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi de commande'),
        leading: IconButton(
          tooltip: 'Retour au compte',
          onPressed: () => context.go('/compte'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser le suivi',
            onPressed: () => ref.invalidate(orderTrackingProvider(documentId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: order.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _TrackingError(
              message: error is ApiException
                  ? error.userMessage
                  : 'Impossible de charger le suivi de cette commande.',
              onRetry: () => ref.invalidate(orderTrackingProvider(documentId)),
            ),
            data: (value) => _TrackingDetails(order: value),
          ),
        ),
      ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
        OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    );
  }
}

class _TrackingDetails extends StatelessWidget {
  const _TrackingDetails({required this.order});

  final CustomerOrder order;

  static const _steps = [
    _TrackingStep('Commande créée', 'awaiting_payment'),
    _TrackingStep('Paiement confirmé', 'payment_confirmed'),
    _TrackingStep('Préparation', 'preparing'),
    _TrackingStep('Expédition', 'shipped'),
    _TrackingStep('Livraison', 'delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 400;
    final currentIndex = switch (order.trackingStatus) {
      'awaiting_payment' => 0,
      'payment_confirmed' => 1,
      'preparing' => 2,
      'shipped' => 3,
      'delivered' => 4,
      _ => -1,
    };
    final trackingCarrier = order.trackingCarrier;
    final trackingNumber = order.trackingNumber;
    final trackingUpdatedAt = order.trackingUpdatedAt;
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.all(compact ? 14 : 20),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order.documentId}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Passée le ${_formatDate(order.createdAt)}'
                  ' · ${_formatEuro(order.total)} €',
                ),
                const SizedBox(height: 12),
                Chip(
                  avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text(_trackingStatusLabel(order.trackingStatus)),
                ),
                if (order.trackingStatus == 'cancelled' ||
                    order.status == 'failed' ||
                    order.status == 'cancelled') ...[
                  const SizedBox(height: 8),
                  Text(
                    order.status == 'failed'
                        ? 'Le paiement de cette commande a échoué.'
                        : 'Le suivi de cette commande est annulé.',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Étapes de la commande',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < _steps.length; index++)
          _buildStep(context, _steps[index], index, currentIndex),
        if (trackingCarrier != null ||
            trackingNumber != null ||
            trackingUpdatedAt != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations de livraison',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (trackingCarrier != null) ...[
                    const SizedBox(height: 8),
                    Text('Transporteur : $trackingCarrier'),
                  ],
                  if (trackingNumber != null) ...[
                    const SizedBox(height: 4),
                    const Text('Numéro de suivi'),
                    SelectableText(trackingNumber),
                  ],
                  if (trackingUpdatedAt != null) ...[
                    const SizedBox(height: 8),
                    Text('Mise à jour : ${_formatDate(trackingUpdatedAt)}'),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Les étapes sont actualisées à partir des informations enregistrées '
          'pour votre commande.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context,
    _TrackingStep step,
    int index,
    int currentIndex,
  ) {
    final theme = Theme.of(context);
    final happenedAt = _eventTime(step.status);
    final reached = currentIndex >= index || happenedAt != null;
    final isCurrent = currentIndex == index;
    final color = reached
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final date = happenedAt ??
        switch (step.status) {
          'awaiting_payment' => order.createdAt,
          'payment_confirmed' => order.paidAt,
          'shipped' => order.shippedAt,
          'delivered' => order.deliveredAt,
          _ => null,
        };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(
                  reached ? Icons.check_circle : Icons.circle_outlined,
                  color: color,
                  size: 22,
                ),
                if (index < _steps.length - 1)
                  Container(
                    width: 2,
                    height: 34,
                    color: reached
                        ? theme.colorScheme.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.outlineVariant,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : null,
                      color: reached ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date == null
                        ? (reached ? 'Confirmée' : 'En attente')
                        : _formatDate(date),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _eventTime(String status) {
    for (final event in order.trackingEvents.reversed) {
      if (event.status == status) return event.happenedAt;
    }
    return null;
  }
}

class _TrackingStep {
  const _TrackingStep(this.label, this.status);

  final String label;
  final String status;
}

String _trackingStatusLabel(String status) => switch (status) {
  'awaiting_payment' => 'En attente de paiement',
  'payment_confirmed' => 'Paiement confirmé',
  'preparing' => 'En préparation',
  'shipped' => 'Expédiée',
  'delivered' => 'Livrée',
  'cancelled' => 'Suivi annulé',
  _ => 'Statut non renseigné',
};

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _formatEuro(double amount) =>
    amount.toStringAsFixed(2).replaceAll('.', ',');
