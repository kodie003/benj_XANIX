import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../core/countries.dart';
import '../poddy/poddy.dart';
import 'info.dart';
import 'name_shop.dart' show ConsentTick;

/// First screen: create a benj account. Business name, then a phone number and/or an
/// email (at least one), then the password twice. "Sign in" for owners who have one,
/// Continue with Google at the bottom, About and Privacy in the footer.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with _FormRunner {
  final _auth = AuthService();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Country _country = ghana;
  bool _consent = false;

  void _create() {
    final business = _business.text.trim();
    final phoneTyped = _phone.text.trim().isNotEmpty;
    final email = _email.text.trim();
    final e164 = phoneTyped ? _country.toE164(_phone.text) : null;
    if (business.isEmpty) return _fail('Type your business name.');
    if (!phoneTyped && email.isEmpty) return _fail('Add a phone number or an email, so you can sign in.');
    if (phoneTyped && e164 == null) return _fail(phoneError(_country));
    if (email.isNotEmpty && !AuthService.looksLikeEmail(email)) return _fail("That email doesn't look right.");
    if (_password.text.length < 6) return _fail('Use a password of at least 6 characters.');
    if (_password.text != _confirm.text) return _fail("The two passwords don't match.");
    if (!_consent) return _fail('Please tick the box so benj can keep your stock records.');
    PendingShop.set(business, phone: e164 ?? '');
    run(() async {
      try {
        await _auth.createBenjAccount(business: business, phone: e164, email: email.isEmpty ? null : email.toLowerCase(), password: _password.text);
      } catch (_) {
        PendingShop.clear();
        rethrow;
      }
    }, AuthService.friendly, signsIn: true);
  }

  void _fail(String message) => setState(() {
        error = message;
        oops++;
      });

  Future<void> _google() => run(_auth.signInWithGoogle, AuthService.friendly);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const pad = EdgeInsets.all(14);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: BenjLogo(height: 56)),
                  const SizedBox(height: 10),
                  Text('Know what to do with your shop this week.', textAlign: TextAlign.center, style: text.bodyLarge),
                  // First hello: Poddy hovers here, like on day one, with a short greeting.
                  SizedBox(height: 150, child: PoddyView(mood: busy ? 'present' : 'hello', flash: 'sad', flashTick: oops)),
                  const Center(child: _Bubble("Hi! I'm Poddy. Let's set up your shop.")),
                  const SizedBox(height: 18),
                  Text('Create a benj account', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _business,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Business name', hintText: 'e.g. Ama Provisions', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  PhoneField(country: _country, controller: _phone, onCountry: (c) => setState(() => _country = c), optional: true),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      helperText: 'Add a phone, an email, or both. With an email you can reset a forgotten password.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(controller: _password, label: 'Password', helper: 'At least 6 characters', isNew: true),
                  const SizedBox(height: 12),
                  PasswordField(controller: _confirm, label: 'Repeat password', isNew: true, onSubmitted: () => busy ? null : _create()),
                  ConsentTick(value: _consent, onChanged: (v) => setState(() => _consent = v)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : _create,
                    child: Padding(padding: pad, child: Text(busy ? 'Please wait…' : 'Create my account')),
                  ),
                  const SizedBox(height: 8),
                  ...messages(),
                  Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('Already have a benj account?', style: text.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SignInScreen())),
                      child: const Text('Sign in'),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or')), Expanded(child: Divider())]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _google,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Padding(padding: pad, child: Text('Continue with Google')),
                  ),
                  const SizedBox(height: 14),
                  const InfoFooter(),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ghana numbers should be 10 digits, starting with 0." One short line per country.
String phoneError(Country c) => '${c.name} numbers should be ${c.digits} digits${c.dropZero ? ', starting with 0' : ''}.';

/// Country dropdown (Ghana first, +233) and the local number, digits only.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.country, required this.controller, required this.onCountry, this.optional = false});
  final Country country;
  final TextEditingController controller;
  final ValueChanged<Country> onCountry;
  final bool optional;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 118,
          child: DropdownButtonFormField<Country>(
            initialValue: country,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 16)),
            selectedItemBuilder: (_) => [for (final c in countries) Text('${c.flag} +${c.code}')],
            items: [for (final c in countries) DropdownMenuItem(value: c, child: Text('${c.flag} ${c.name} +${c.code}', overflow: TextOverflow.ellipsis))],
            onChanged: (c) {
              if (c != null) onCountry(c);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(country.digits)],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: optional ? 'Phone (optional)' : 'Phone number',
              hintText: country.hint,
              helperText: '${country.digits} digits',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ]);
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

mixin _FormRunner<T extends StatefulWidget> on State<T> {
  bool busy = false;
  int oops = 0;
  String? error, info;

  Future<void> run(Future<void> Function() job, String Function(Object) explain, {bool signsIn = false}) async {
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await job();
      // Signed in: close any form on top; the app behind it has already switched.
      if (signsIn && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = explain(e);
          oops++;
        });
      }
    }
    if (mounted) setState(() => busy = false);
  }

  List<Widget> messages() {
    final scheme = Theme.of(context).colorScheme;
    return [
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600))),
      if (info != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(info!, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600))),
    ];
  }
}

/// Signing back in: business name, phone or email, and the password.
/// A forgotten password is reset through the account's email.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with _FormRunner {
  final _auth = AuthService();
  final _who = TextEditingController();
  final _password = TextEditingController();

  void _submit() {
    if (_who.text.trim().isEmpty) {
      setState(() => error = 'Type your business name, phone or email.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => error = 'Type your password.');
      return;
    }
    run(() => _auth.signInAny(_who.text, _password.text), AuthService.friendly, signsIn: true);
  }

  void _forgot() {
    if (_who.text.trim().isEmpty) {
      setState(() => error = 'Type your business name, phone or email first, then tap Forgot password.');
      return;
    }
    run(() async {
      await _auth.requestReset(_who.text);
      if (mounted) {
        setState(() => info = "If your account has an email, we've sent it a link to reset your password. No email on your account? Write to $supportEmail.");
      }
    }, AuthService.friendly);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => Navigator.of(context).maybePop()), title: const Text('Sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(height: 160, child: PoddyView(mood: busy ? 'present' : 'hello', flash: 'sad', flashTick: oops)),
                  const Center(child: _Bubble('Heyy, good to see you!')),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _who,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Business name, phone or email', hintText: 'e.g. Ama Provisions', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(controller: _password, label: 'Password', onSubmitted: () => busy ? null : _submit()),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : _forgot, child: const Text('Forgot password?'))),
                  FilledButton(onPressed: busy ? null : _submit, child: Padding(padding: const EdgeInsets.all(14), child: Text(busy ? 'Please wait…' : 'Sign in'))),
                  const SizedBox(height: 10),
                  ...messages(),
                  Text('Signed up with Google? Go back and tap Continue with Google.', textAlign: TextAlign.center, style: text.bodySmall),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A password box with the little eye to show or hide what was typed.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.helper, this.isNew = false, this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool isNew;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: !_show,
        autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
        onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _show ? 'Hide password' : 'Show password',
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      );
}
