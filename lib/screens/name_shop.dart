import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../poddy/poddy.dart';

/// Only for accounts that have no shop yet (Google sign-in, or older accounts).
/// Account creation forms ask for the business name directly.
class NameShopScreen extends StatefulWidget {
  const NameShopScreen({super.key, required this.repo, required this.user, required this.onSignOut});
  final ShopRepo repo;
  final User user;
  final VoidCallback onSignOut;

  @override
  State<NameShopScreen> createState() => _NameShopScreenState();
}

class _NameShopScreenState extends State<NameShopScreen> {
  final _name = TextEditingController();
  bool _consent = false, _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "Type your shop's name.");
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Please tick the box so benj can keep your stock records.');
      return;
    }
    setState(() => _busy = true);
    final phone = AuthService.accountLabel(widget.user);
    await widget.repo.saveShop(Shop(name: _name.text.trim(), ownerPhone: phone.startsWith('+') ? phone : ''));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BenjLogo(height: 26),
        actions: [TextButton(onPressed: widget.onSignOut, child: const Text('Sign out'))],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 160, child: PoddyView(mood: 'hello')),
              Text("What's your shop called?", textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Business name', hintText: 'e.g. Ama Provisions', border: OutlineInputBorder()),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              ConsentTick(value: _consent, onChanged: (v) => setState(() => _consent = v)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _busy ? null : _save, child: const Padding(padding: EdgeInsets.all(14), child: Text('Open my shop'))),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// PRD: owner data is private and kept only with consent.
class ConsentTick extends StatelessWidget {
  const ConsentTick({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Keep my stock records in my benj account. Only I can see them.'),
      );
}
