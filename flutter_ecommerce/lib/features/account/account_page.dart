import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import 'auth_repository.dart';
import 'auth_session.dart';
import 'order_repository.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registering = false;
  bool _submitting = false;
  bool _redirecting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final session = _registering
          ? await repository.register(
              username: _usernameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await repository.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      final destination = _safeReturnLocation(widget.returnTo);
      if (destination != null) _redirecting = true;
      ref.read(authSessionProvider.notifier).signIn(session);
      if (mounted) context.go(destination ?? '/');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final destination = _safeReturnLocation(widget.returnTo);
    if (session != null && destination != null && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(destination);
      });
    }
    final orders = session == null ? null : ref.watch(customerOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte TLveta'),
        leading: IconButton(
          tooltip: 'Retour à la boutique',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: session == null ? 460 : 1040),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
            ),
            child: session == null
                ? _buildForm()
                : _buildSignedIn(session, orders!),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          _registering ? 'Créer un compte client' : 'Connexion client',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ce compte client est distinct du compte administrateur Strapi.',
        ),
        const SizedBox(height: 24),
        if (_registering) ...[
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nom d’utilisateur'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Adresse e-mail'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: 'Mot de passe'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_registering ? 'Créer mon compte' : 'Se connecter'),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() {
                  _registering = !_registering;
                  _error = null;
                }),
          child: Text(
            _registering ? 'J’ai déjà un compte' : 'Créer un compte client',
          ),
        ),
      ],
    );
  }

  Widget _buildSignedIn(
    AuthSession session,
    AsyncValue<List<CustomerOrder>> orders,
  ) {
    final summary = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 52,
                    child: session.avatarUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFECEDE7),
                            child: Icon(Icons.person_outline),
                          )
                        : Image.network(
                            session.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(
                                  color: Color(0xFFECEDE7),
                                  child: Icon(Icons.person_outline),
                                ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour ${session.displayName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        session.email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/profil'),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Modifier mon profil'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.push('/panier'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Voir mon panier'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                ref.read(authSessionProvider.notifier).signOut();
                ref.invalidate(customerOrdersProvider);
                context.go('/');
              },
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
    final orderHistory = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mes commandes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(
            error is ApiException
                ? error.userMessage
                : 'Impossible de charger les commandes.',
          ),
          data: (items) => items.isEmpty
              ? const Text('Aucune commande pour le moment.')
              : Column(
                  children: [
                    for (final order in items)
                      Card(
                        child: ListTile(
                          onTap: () => context.push(
                            '/commandes/${order.documentId}/suivi',
                          ),
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(
                            _trackingStatusLabel(order.trackingStatus),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatOrderDate(order.createdAt)} · '
                            '${order.total.toStringAsFixed(2).replaceAll('.', ',')} €'
                            '\n${_orderStatusLabel(order.status)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 740) {
          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: summary),
                const SizedBox(width: 24),
                Expanded(child: orderHistory),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 24), orderHistory],
          ),
        );
      },
    );
  }
}

String? _safeReturnLocation(String? location) {
  if (location == null) {
    return null;
  }
  final uri = Uri.tryParse(location);
  if (uri == null || uri.hasScheme || uri.hasAuthority || !uri.path.startsWith('/')) {
    return null;
  }
  if (RegExp(r'^/produit/[A-Za-z0-9_-]+$').hasMatch(uri.path) &&
      uri.queryParameters.isEmpty) {
    return uri.toString();
  }
  if (uri.path == '/' &&
      uri.queryParameters.length == 1 &&
      RegExp(r'^[A-Za-z0-9_-]+$')
          .hasMatch(uri.queryParameters['livraison'] ?? '')) {
    return uri.toString();
  }
  return null;
}

String _orderStatusLabel(String status) => switch (status) {
  'pending' => 'En attente de paiement',
  'paid' => 'Payée',
  'failed' => 'Échec du paiement',
  'cancelled' => 'Annulée',
  _ => 'Commande',
};

String _trackingStatusLabel(String status) => switch (status) {
  'awaiting_payment' => 'En attente de paiement',
  'payment_confirmed' => 'Paiement confirmé',
  'preparing' => 'En préparation',
  'shipped' => 'Expédiée',
  'delivered' => 'Livrée',
  'cancelled' => 'Suivi annulé',
  _ => 'Suivi indisponible',
};

String _formatOrderDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
