import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../shared/theme/app_theme.dart';
import '../account/auth_session.dart';
import '../catalog/catalog_providers.dart';
import '../cart/cart_repository.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authSessionProvider) == null) {
      final loginLocation = Uri(
        path: '/compte',
        queryParameters: {'retour': '/produit/$documentId'},
      );
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Retour au catalogue',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 42),
                const SizedBox(height: 16),
                Text(
                  'Connectez-vous pour consulter ce produit et poursuivre '
                  'votre achat.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push(loginLocation.toString()),
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final product = ref.watch(productDetailProvider(documentId));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.canvas,
        leading: IconButton(
          tooltip: 'Retour au catalogue',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Détail du produit'),
      ),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiException
                  ? error.userMessage
                  : 'Impossible de charger ce produit.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (item) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final images = item.imageUrls.isEmpty
                      ? <String?>[null]
                      : item.imageUrls.map<String?>((url) => url).toList();
                  final image = AspectRatio(
                    aspectRatio: compact ? 1.2 : 1,
                    child: images.first == null
                        ? const ColoredBox(
                            color: Color(0xFFECEDE7),
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: AppTheme.muted,
                            ),
                          )
                        : PageView.builder(
                            itemCount: images.length,
                            itemBuilder: (context, index) => Image.network(
                              images[index]!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(
                                    color: Color(0xFFECEDE7),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                            ),
                          ),
                  );
                  final details = Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.category != null)
                          Text(
                            item.category!.name.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          item.description?.trim().isNotEmpty == true
                              ? item.description!
                              : 'Aucune description n’a été renseignée.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          item.price == null
                              ? 'Tarif à renseigner dans le catalogue'
                              : 'Prix : ${item.price!.toStringAsFixed(2).replaceAll('.', ',')} €',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: item.price == null
                              ? null
                              : () => _addToCart(context, ref, item.documentId),
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Ajouter au panier'),
                        ),
                      ],
                    ),
                  );

                  if (compact) {
                    return ListView(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: image,
                        ),
                        const SizedBox(height: 12),
                        details,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: image,
                        ),
                      ),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    String documentId,
  ) async {
    if (ref.read(authSessionProvider) == null) {
      context.push('/compte');
      return;
    }
    try {
      await ref.read(cartRepositoryProvider).addProduct(documentId);
      ref.invalidate(customerCartProvider);
      if (context.mounted) context.push('/panier');
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }
}
