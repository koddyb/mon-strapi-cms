import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../shared/theme/app_theme.dart';
import '../account/auth_session.dart';
import 'cart_repository.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon panier')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.push('/compte'),
            child: const Text('Connectez-vous pour accéder à votre panier'),
          ),
        ),
      );
    }

    final cart = ref.watch(customerCartProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon panier'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiException
                  ? error.userMessage
                  : 'Panier indisponible.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (value) => value.items.isEmpty
            ? const Center(child: Text('Votre panier est vide.'))
            : _CartContents(cart: value),
      ),
    );
  }
}

class _CartContents extends ConsumerWidget {
  const _CartContents({required this.cart});

  final CustomerCart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPrices = cart.hasPrices;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final item in cart.items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: item.product.imageUrl == null
                                ? const Icon(Icons.image_outlined)
                                : Image.network(
                                    item.product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.product.price == null
                                      ? 'Tarif à renseigner'
                                      : '${_formatEuro(item.product.price!)} € par article',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retirer du panier',
                            onPressed: () =>
                                _removeLine(context, ref, item.documentId),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Diminuer la quantité',
                            onPressed: item.quantity > 1
                                ? () => _updateQuantity(
                                    context,
                                    ref,
                                    item,
                                    item.quantity - 1,
                                  )
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            tooltip: 'Augmenter la quantité',
                            onPressed: item.quantity < 99
                                ? () => _updateQuantity(
                                    context,
                                    ref,
                                    item,
                                    item.quantity + 1,
                                  )
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Sous-total : ${_formatEuro(cart.subtotal)} €',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text('Livraison France / UE : 4,00 €'),
            const SizedBox(height: 6),
            Text(
              'Total : ${_formatEuro(cart.subtotal + 4)} €',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: hasPrices ? () => _checkout(context, ref) : null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Continuer vers le paiement'),
            ),
            if (!hasPrices) ...[
              const SizedBox(height: 10),
              const Text(
                'Le paiement sera activé lorsque chaque produit aura un tarif '
                'EUR renseigné dans Strapi.',
                style: TextStyle(color: AppTheme.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateQuantity(
    BuildContext context,
    WidgetRef ref,
    CartItem item,
    int quantity,
  ) async {
    try {
      await ref
          .read(cartRepositoryProvider)
          .updateQuantity(item.documentId, quantity);
      ref.invalidate(customerCartProvider);
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error.userMessage);
    }
  }

  Future<void> _removeLine(
    BuildContext context,
    WidgetRef ref,
    String lineId,
  ) async {
    try {
      await ref.read(cartRepositoryProvider).removeLine(lineId);
      ref.invalidate(customerCartProvider);
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error.userMessage);
    }
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    try {
      final order = await ref
          .read(cartRepositoryProvider)
          .createCheckoutOrder();
      if (context.mounted) context.push('/paiement/${order.documentId}');
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

String _formatEuro(double amount) =>
    amount.toStringAsFixed(2).replaceAll('.', ',');
