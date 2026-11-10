import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../account/order_repository.dart';
import 'cart_repository.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({required this.documentId, super.key});

  final String documentId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  CustomerOrder? _order;
  DateTime? _readyAt;
  Timer? _countdownTimer;
  int _secondsRemaining = 10;
  bool _loadingOrder = true;
  bool _startingSimulation = false;
  bool _confirmingPayment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .getOrder(widget.documentId);
      if (mounted) setState(() => _order = order);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _loadingOrder = false);
    }
  }

  Future<void> _startSimulation() async {
    setState(() {
      _startingSimulation = true;
      _error = null;
    });
    try {
      final readyAt = await ref
          .read(orderRepositoryProvider)
          .startPaymentSimulation(widget.documentId);
      if (!mounted) return;
      _readyAt = readyAt;
      _updateCountdown();
      _countdownTimer ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _updateCountdown(),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _startingSimulation = false);
    }
  }

  void _updateCountdown() {
    final readyAt = _readyAt;
    if (readyAt == null || _confirmingPayment || !mounted) return;
    final remaining = readyAt.difference(DateTime.now()).inMilliseconds;
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _confirmPayment();
      return;
    }
    final seconds = (remaining / 1000).ceil();
    if (seconds != _secondsRemaining) {
      setState(() => _secondsRemaining = seconds);
    }
  }

  Future<void> _confirmPayment() async {
    if (_confirmingPayment) return;
    setState(() {
      _confirmingPayment = true;
      _error = null;
    });
    try {
      await ref
          .read(orderRepositoryProvider)
          .confirmPayment(widget.documentId);
      ref.invalidate(customerCartProvider);
      ref.invalidate(customerOrdersProvider);
      if (mounted) context.go('/?livraison=${widget.documentId}');
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _confirmingPayment = false;
          _error = error.userMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          tooltip: 'Retour au panier',
          onPressed: () => context.go('/panier'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 400 ? 12 : 24,
                  ),
                  child: _loadingOrder
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null && _order == null
                      ? _buildError(context)
                      : _buildPayment(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 42),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _loadOrder,
          child: const Text('Réessayer'),
        ),
      ],
    );
  }

  Widget _buildPayment(BuildContext context) {
    final order = _order!;
    final simulating = _readyAt != null;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 400 ? 16 : 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFF635BFF)),
                const SizedBox(width: 10),
                Text(
                  'Paiement',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                const Text(
                  'stripe',
                  style: TextStyle(
                    color: Color(0xFF635BFF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E4EC)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.credit_card_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Carte bancaire de démonstration',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.check_circle, color: Color(0xFF635BFF)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Text('Commande')),
                Flexible(
                  child: Text(
                    '#${order.documentId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Total, livraison comprise')),
                Text(
                  '${order.total.toStringAsFixed(2).replaceAll('.', ',')} €',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (order.status == 'paid') ...[
              const Text(
                'Cette commande a déjà été payée.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/?livraison=${widget.documentId}'),
                child: const Text('Renseigner l’adresse de livraison'),
              ),
            ] else if (order.status != 'pending') ...[
              Text(
                'Cette commande n’est plus en attente de paiement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ] else if (simulating) ...[
              const Text(
                'Simulation en cours. Aucune donnée bancaire réelle n’est '
                'demandée ni transmise.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (_confirmingPayment)
                const Center(child: CircularProgressIndicator())
              else
                if (_error != null)
                  FilledButton(
                    onPressed: _confirmPayment,
                    child: const Text('Réessayer la confirmation'),
                  )
                else
                  Text(
                    'Confirmation dans $_secondsRemaining s',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
            ] else ...[
              const Text(
                'Démonstration uniquement : ce parcours affiche une interface '
                'inspirée de Stripe, sans encaisser de paiement réel.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _startingSimulation ? null : _startSimulation,
                icon: _startingSimulation
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: const Text('Simuler le paiement'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
