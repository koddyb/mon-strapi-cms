import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/catalog/catalog_page.dart';
import 'features/account/account_page.dart';
import 'features/account/profile_page.dart';
import 'features/cart/cart_page.dart';
import 'features/cart/payment_page.dart';
import 'features/products/product_detail_page.dart';
import 'shared/theme/app_theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => CatalogPage(
        shippingOrderDocumentId: state.uri.queryParameters['livraison'],
      ),
    ),
    GoRoute(
      path: '/compte',
      builder: (context, state) => AccountPage(
        returnTo: state.uri.queryParameters['retour'],
      ),
    ),
    GoRoute(
      path: '/profil',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(path: '/panier', builder: (context, state) => const CartPage()),
    GoRoute(
      path: '/paiement/:documentId',
      builder: (context, state) => PaymentPage(
        documentId: state.pathParameters['documentId']!,
      ),
    ),
    GoRoute(
      path: '/produit/:documentId',
      builder: (context, state) =>
          ProductDetailPage(documentId: state.pathParameters['documentId']!),
    ),
  ],
);

class TlvetaApp extends StatelessWidget {
  const TlvetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TLveta | La boutique',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
