import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import 'auth_session.dart';
import 'profile_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authSessionProvider) == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon profil')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/compte'),
            child: const Text('Connectez-vous pour acc?der ? votre profil'),
          ),
        ),
      );
    }

    final profile = ref.watch(customerProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        leading: IconButton(
          tooltip: 'Retour au compte',
          onPressed: () => context.go('/compte'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: profile.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ProfileError(
                message: error is ApiException
                    ? error.userMessage
                    : 'Impossible de charger votre profil.',
                onRetry: () => ref.invalidate(customerProfileProvider),
              ),
              data: (value) => _ProfileForm(profile: value),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('R?essayer')),
      ],
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final CustomerProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(
    text: widget.profile.firstName,
  );
  late final _lastNameController = TextEditingController(
    text: widget.profile.lastName,
  );
  late final _phoneController = TextEditingController(
    text: widget.profile.phoneNumber,
  );
  late final _avatarController = TextEditingController(
    text: widget.profile.avatarUrl,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await ref.read(profileRepositoryProvider).updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        avatarUrl: _avatarController.text.trim(),
      );
      ref.read(authSessionProvider.notifier).updateProfile(
        firstName: profile.firstName,
        lastName: profile.lastName,
        avatarUrl: profile.avatarUrl,
      );
      ref.invalidate(customerProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis ? jour.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateAvatarUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return 'Saisissez une URL d?image HTTP ou HTTPS valide.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _avatarController.text.trim();
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Center(
            child: ClipOval(
              child: SizedBox.square(
                dimension: 104,
                child: imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFECEDE7),
                        child: Icon(Icons.person_outline, size: 48),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: Color(0xFFECEDE7),
                              child: Icon(Icons.broken_image_outlined, size: 40),
                            ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Informations personnelles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            textInputAction: TextInputAction.next,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Pr?nom'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            textInputAction: TextInputAction.next,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: widget.profile.email,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Adresse e-mail'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 32,
            decoration: const InputDecoration(labelText: 'T?l?phone'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _avatarController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            maxLength: 2048,
            validator: _validateAvatarUrl,
            decoration: const InputDecoration(
              labelText: 'Lien de la photo de profil',
              helperText: 'Ajoutez une URL publique HTTPS. Aper?u apr?s sauvegarde.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer mon profil'),
          ),
          const SizedBox(height: 8),
          Text(
            'Compte : ${widget.profile.username}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
