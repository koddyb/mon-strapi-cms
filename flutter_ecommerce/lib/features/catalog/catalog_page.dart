import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../shared/theme/app_theme.dart';
import '../account/auth_session.dart';
import '../account/order_repository.dart';
import '../categories/category.dart';
import '../products/product.dart';
import 'catalog_providers.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, this.shippingOrderDocumentId});

  final String? shippingOrderDocumentId;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _searchController = TextEditingController();
  final _catalogAnchor = GlobalKey();
  Timer? _searchDebounce;
  String _search = '';
  String? _categoryId;
  String _sort = 'title:asc';

  CatalogQuery get _query =>
      (categoryId: _categoryId, search: _search, sort: _sort);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToCatalog() {
    final context = _catalogAnchor.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(productCategoriesProvider);
    final products = ref.watch(catalogProductsProvider(_query));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _SiteHeader(onExplore: _scrollToCatalog)),
          SliverToBoxAdapter(child: _HeroBanner(onExplore: _scrollToCatalog)),
          if (widget.shippingOrderDocumentId != null)
            SliverToBoxAdapter(
              child: ShippingAddressCard(
                orderDocumentId: widget.shippingOrderDocumentId!,
              ),
            ),
          SliverToBoxAdapter(
            child: _CatalogHeading(
              key: _catalogAnchor,
              searchController: _searchController,
              search: _search,
              sort: _sort,
              categories: categories,
              categoryId: _categoryId,
              onCategorySelected: (categoryId) {
                setState(() => _categoryId = categoryId);
              },
              onSortSelected: (sort) => setState(() => _sort = sort),
              onSearchChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) {
                    setState(() => _search = value.trim());
                  }
                });
              },
            ),
          ),
          products.when(
            loading: () => const SliverToBoxAdapter(child: _LoadingCatalog()),
            error: (error, stackTrace) => SliverToBoxAdapter(
              child: _CatalogError(
                error: error,
                onRetry: () {
                  ref.invalidate(catalogProductsProvider(_query));
                  ref.invalidate(productCategoriesProvider);
                },
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverToBoxAdapter(child: _EmptyCatalog())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 64),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.crossAxisExtent
                            .clamp(0.0, 1160.0)
                            .toDouble();
                        final columns = ((maxWidth + 20) / 290)
                            .floor()
                            .clamp(1, 4)
                            .toInt();
                        final sidePadding =
                            ((constraints.crossAxisExtent - maxWidth) / 2)
                                .clamp(0.0, 100.0)
                                .toDouble();
                        return SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: sidePadding,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _ProductCard(product: items[index]),
                              childCount: items.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 20,
                                  mainAxisExtent: columns == 1 ? 390 : 365,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: _SiteFooter()),
        ],
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final veryCompact = constraints.maxWidth < 440;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: veryCompact ? 12 : compact ? 20 : 32,
                vertical: 18,
              ),
              child: Row(
                children: [
                  const _BrandMark(),
                  const Spacer(),
                  if (!compact) ...[
                    TextButton(
                      onPressed: onExplore,
                      child: const Text('La boutique'),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: onExplore,
                      child: const Text('Nos collections'),
                    ),
                    const SizedBox(width: 22),
                  ],
                  if (!veryCompact)
                    IconButton(
                      tooltip: 'Aller au catalogue',
                      onPressed: onExplore,
                      icon: const Icon(Icons.search),
                    ),
                  IconButton(
                    tooltip: 'Mon panier',
                    onPressed: () => context.push('/panier'),
                    icon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  const SizedBox(width: 4),
                  if (veryCompact)
                    IconButton(
                      tooltip: 'Mon compte',
                      onPressed: () => context.push('/compte'),
                      icon: const Icon(Icons.person_outline),
                    )
                  else
                    TextButton(
                      onPressed: () => context.push('/compte'),
                      child: const Text('Mon compte'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: ClipRect(
            child: Transform.scale(
              scale: 2.1,
              child: Image.asset(
                'assets/images/tlveta-logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TLveta',
              style: TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'LA BOUTIQUE',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 9,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final veryCompact = constraints.maxWidth < 440;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.forest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      right: -34,
                      top: -106,
                      child: _HeroOrnament(),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        veryCompact ? 18 : compact ? 24 : 64,
                        veryCompact ? 32 : compact ? 44 : 70,
                        veryCompact ? 18 : compact ? 24 : 64,
                        veryCompact ? 36 : compact ? 48 : 74,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LA TECHNOLOGIE AU QUOTIDIEN',
                              style: TextStyle(
                                color: Color(0xFFE0B990),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.1,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'La technologie\nqui vous accompagne.',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: veryCompact
                                        ? 32
                                        : compact
                                        ? 40
                                        : 54,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Audio, informatique et objets connectés '
                              'sélectionnés pour vous.',
                              style: TextStyle(
                                color: Color(0xFFD2D9D1),
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 30),
                            FilledButton.icon(
                              onPressed: onExplore,
                              icon: const Icon(Icons.arrow_downward, size: 17),
                              label: const Text('Explorer le catalogue'),
                              style: FilledButton.styleFrom(
                                foregroundColor: AppTheme.ink,
                                backgroundColor: const Color(0xFFE3B58E),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroOrnament extends StatelessWidget {
  const _HeroOrnament();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 390,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 305,
            height: 305,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ),
          Container(
            width: 235,
            height: 235,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          Transform.rotate(
            angle: -0.45,
            child: Container(
              width: 92,
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFFE0B990).withValues(alpha: 0.16),
                border: Border.all(
                  color: const Color(0xFFE0B990).withValues(alpha: 0.46),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogHeading extends StatelessWidget {
  const _CatalogHeading({
    super.key,
    required this.searchController,
    required this.search,
    required this.sort,
    required this.categories,
    required this.categoryId,
    required this.onCategorySelected,
    required this.onSortSelected,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final String search;
  final String sort;
  final AsyncValue<List<ProductCategory>> categories;
  final String? categoryId;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onSortSelected;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            MediaQuery.sizeOf(context).width < 600 ? 40 : 64,
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LE CATALOGUE TLVETA',
                style: TextStyle(
                  color: AppTheme.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Nos produits',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Retrouvez les produits publiés dans notre catalogue.',
                style: TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final searchField = TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un produit',
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                  final sortField = DropdownButtonFormField<String>(
                    initialValue: sort,
                    decoration: const InputDecoration(labelText: 'Trier par'),
                    items: const [
                      DropdownMenuItem(
                        value: 'title:asc',
                        child: Text('Nom, A à Z'),
                      ),
                      DropdownMenuItem(
                        value: 'title:desc',
                        child: Text('Nom, Z à A'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onSortSelected(value);
                    },
                  );
                  if (compact) {
                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        sortField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: searchField),
                      const SizedBox(width: 14),
                      SizedBox(width: 220, child: sortField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _CategoryFilters(
                categories: categories,
                selectedCategoryId: categoryId,
                onSelected: onCategorySelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final AsyncValue<List<ProductCategory>> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      loading: () => const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => Text(
        'Les filtres par catégorie sont indisponibles : ${_shortError(error)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      data: (items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _CategoryChip(
            label: 'Tout voir',
            selected: selectedCategoryId == null,
            onPressed: () => onSelected(null),
          ),
          for (final category in items)
            _CategoryChip(
              label: category.name,
              selected: selectedCategoryId == category.documentId,
              onPressed: () => onSelected(category.documentId),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPressed(),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFDCE7DF),
      side: BorderSide(
        color: selected ? AppTheme.forest : const Color(0xFFE4E5DE),
      ),
      labelStyle: TextStyle(
        color: selected ? AppTheme.forest : AppTheme.muted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productLocation = '/produit/${product.documentId}';
    final compactCard = MediaQuery.sizeOf(context).width < 600;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (ref.read(authSessionProvider) == null) {
            final loginLocation = Uri(
              path: '/compte',
              queryParameters: {'retour': productLocation},
            );
            context.push(loginLocation.toString());
            return;
          }
          context.push(productLocation);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _ProductImage(imageUrl: product.imageUrl)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compactCard ? 12 : 18,
                compactCard ? 12 : 16,
                compactCard ? 12 : 18,
                compactCard ? 13 : 17,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.category != null)
                    Text(
                      product.category!.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.orange,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 7),
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: compactCard
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    product.description?.trim().isNotEmpty == true
                        ? product.description!
                        : 'Description non renseignée.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.price == null
                              ? 'Tarif à renseigner'
                              : '${product.price!.toStringAsFixed(2).replaceAll('.', ',')} €',
                          style: TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 17,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _ImagePlaceholder();
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ImagePlaceholder(loading: true);
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFECEDE7),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(
                Icons.image_outlined,
                color: Color(0xFF9CA49A),
                size: 38,
              ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).userMessage
        : 'Une erreur inattendue empêche de charger les produits.';
    final forbidden =
        error is ApiException && (error as ApiException).statusCode == 403;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 56),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE7E8E2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  forbidden ? Icons.lock_outline : Icons.cloud_off_outlined,
                  color: AppTheme.orange,
                  size: 28,
                ),
                const SizedBox(height: 16),
                Text(
                  forbidden
                      ? 'Accès au catalogue refusé'
                      : 'Catalogue indisponible',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                if (forbidden) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Aucune donnée de démonstration n’est affichée. '
                    'Dans Strapi, active la permission find du rôle Public '
                    'pour les produits et les catégories, puis recharge cette page.',
                    style: TextStyle(color: AppTheme.muted, height: 1.55),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCatalog extends StatelessWidget {
  const _LoadingCatalog();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Chargement du catalogue Strapi…'),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 64),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 38,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 14),
            Text(
              'Aucun produit trouvé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            const Text(
              'Essaie un autre mot-clé ou une autre catégorie.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF202D27),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: const Center(
        child: Text(
          'TLveta  ·  Boutique en ligne',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFC8D0C8), fontSize: 12),
        ),
      ),
    );
  }
}

String _shortError(Object error) {
  if (error is ApiException && error.statusCode == 403) {
    return 'permission de lecture manquante';
  }
  return 'indisponibles';
}

class ShippingAddressCard extends ConsumerStatefulWidget {
  const ShippingAddressCard({required this.orderDocumentId, super.key});

  final String orderDocumentId;

  @override
  ConsumerState<ShippingAddressCard> createState() =>
      _ShippingAddressCardState();
}

class _ShippingAddressCardState extends ConsumerState<ShippingAddressCard> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'France');
  final _phoneController = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    if (ref.read(authSessionProvider) == null) {
      final returnTo = Uri(
        path: '/',
        queryParameters: {'livraison': widget.orderDocumentId},
      );
      context.push(
        Uri(
          path: '/compte',
          queryParameters: {'retour': returnTo.toString()},
        ).toString(),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(orderRepositoryProvider)
          .saveShippingAddress(
            widget.orderDocumentId,
            address: {
              'fullName': _fullNameController.text.trim(),
              'line1': _line1Controller.text.trim(),
              'line2': _line2Controller.text.trim(),
              'postalCode': _postalCodeController.text.trim(),
              'city': _cityController.text.trim(),
              'country': _countryController.text.trim(),
              'phone': _phoneController.text.trim(),
            },
          );
      ref.invalidate(customerOrdersProvider);
      if (mounted) setState(() => _saved = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
            24,
            MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
            8,
          ),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
              ),
              child: _saved ? _buildConfirmation(context) : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paiement accepté',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Indiquez où vous souhaitez recevoir votre commande.',
          ),
          const SizedBox(height: 20),
          _addressField(_fullNameController, 'Nom complet'),
          _addressField(_line1Controller, 'Adresse'),
          _addressField(
            _line2Controller,
            'Complément d’adresse (facultatif)',
            required: false,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final postalCode = _addressField(
                _postalCodeController,
                'Code postal',
              );
              final city = _addressField(_cityController, 'Ville');
              if (constraints.maxWidth < 560) {
                return Column(children: [postalCode, city]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: postalCode),
                  const SizedBox(width: 12),
                  Expanded(child: city),
                ],
              );
            },
          ),
          _addressField(_countryController, 'Pays'),
          _addressField(
            _phoneController,
            'Téléphone (facultatif)',
            required: false,
            keyboardType: TextInputType.phone,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _saveAddress,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: const Text('Valider l’adresse de livraison'),
          ),
        ],
      ),
    );
  }

  Widget _addressField(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: 120,
        decoration: InputDecoration(labelText: label, counterText: ''),
        validator: (value) {
          if (!required) return null;
          if (value == null || value.trim().isEmpty) {
            return 'Ce champ est obligatoire.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 36),
        const SizedBox(height: 12),
        Text(
          'Adresse de livraison enregistrée',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Merci pour votre commande.'),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () =>
              context.go('/commandes/${widget.orderDocumentId}/suivi'),
          child: const Text('Suivre ma commande'),
        ),
      ],
    );
  }
}
