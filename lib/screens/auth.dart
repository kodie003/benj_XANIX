import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../core/countries.dart';
import '../poddy/poddy.dart';
import 'info.dart';
import 'name_shop.dart' show ConsentTick;

/// The first screen is the sign-up form for a benj account: business name, phone
/// number (Ghana +233 by default, other countries in a dropdown), password twice.
/// Google and email come after; existing owners tap "Sign in". About and Privacy
/// sit in the footer. (SMS codes are paused; see AuthService.)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with _FormRunner {
  final _auth = AuthService();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Country _country = ghana;
  bool _consent = false;

  void _create() {
    final e164 = _country.toE164(_phone.text);
    if (_business.text.trim().isEmpty) {
      setState(() => error = 'Type your business name.');
      return;
    }
    if (e164 == null) {
      setState(() => error = phoneError(_country));
      return;
    }
    if (_password.text.length < 6) {
      setState(() => error = 'Use a password of at least 6 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => error = "The two passwords don't match.");
      return;
    }
    if (!_consent) {
      setState(() => error = 'Please tick the box so benj can keep your stock records.');
      return;
    }
    PendingShop.set(_business.text.trim(), phone: e164);
    run(() async {
      try {
        await _auth.signUpPhonePassword(e164, _password.text);
      } catch (_) {
        PendingShop.clear();
        rethrow;
      }
    }, AuthService.friendlyPhone, signsIn: true);
  }

  Future<void> _google() => run(_auth.signInWithGoogle, AuthService.friendly);

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

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
                  PhoneField(country: _country, controller: _phone, onCountry: (c) => setState(() => _country = c)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 6 characters', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => busy ? null : _create(),
                    decoration: const InputDecoration(labelText: 'Repeat password', border: OutlineInputBorder()),
                  ),
                  ConsentTick(value: _consent, onChanged: (v) => setState(() => _consent = v)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : _create,
                    child: Padding(padding: pad, child: Text(busy ? 'Please wait…' : 'Create my account')),
                  ),
                  const SizedBox(height: 8),
                  ...messages(),
                  const SizedBox(height: 14),
                  const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or')), Expanded(child: Divider())]),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _google,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Padding(padding: pad, child: Text('Continue with Google')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _open(const EmailSignInScreen()),
                    icon: const Icon(Icons.mail_outline),
                    label: const Padding(padding: pad, child: Text('Continue with email')),
                  ),
                  const SizedBox(height: 14),
                  Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('Already have a benj account?', style: text.bodyMedium),
                    TextButton(onPressed: () => _open(const PhoneSignInScreen()), child: const Text('Sign in')),
                  ]),
                  const SizedBox(height: 18),
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

String phoneError(Country c) => c.dropZero
    ? 'Enter your ${c.name} number: ${c.digits} digits starting with 0, like ${c.hint}.'
    : 'Enter your ${c.name} number: ${c.digits} digits, like ${c.hint}.';

/// Country dropdown (Ghana first, +233) and the local number, digits only.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.country, required this.controller, required this.onCountry});
  final Country country;
  final TextEditingController controller;
  final ValueChanged<Country> onCountry;

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
            decoration: InputDecoration(labelText: 'Phone number', hintText: country.hint, helperText: '${country.digits} digits', border: const OutlineInputBorder()),
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

/// Poddy hovering above a form, reacting to it: thinking while it works, sad on an error.
class _HoveringPoddy extends StatelessWidget {
  const _HoveringPoddy({required this.busy, required this.oops});
  final bool busy;
  final int oops;

  @override
  Widget build(BuildContext context) => SizedBox(height: 170, child: PoddyView(mood: busy ? 'present' : 'hello', flash: 'sad', flashTick: oops));
}

/// Shared layout for the sign-in forms: back button, Poddy on top, the fields below.
class _FormPage extends StatelessWidget {
  const _FormPage({required this.title, required this.busy, required this.oops, required this.children});
  final String title;
  final bool busy;
  final int oops;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => Navigator.of(context).maybePop()), title: Text(title)),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _HoveringPoddy(busy: busy, oops: oops),
                    const SizedBox(height: 8),
                    ...children,
                  ]),
                ),
              ),
            ),
          ),
        ),
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
      // Signed in: close the form; the app behind it has already switched.
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
      if (error != null) Text(error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
      if (info != null) Text(info!, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
    ];
  }
}

/// Signing back in to a benj account: phone number and password.
class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> with _FormRunner {
  final _auth = AuthService();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  Country _country = ghana;

  void _submit() {
    final e164 = _country.toE164(_phone.text);
    if (e164 == null) {
      setState(() => error = phoneError(_country));
      return;
    }
    run(() => _auth.signInPhonePassword(e164, _password.text), AuthService.friendlyPhone, signsIn: true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormPage(
      title: 'Sign in',
      busy: busy,
      oops: oops,
      children: [
        PhoneField(country: _country, controller: _phone, onCountry: (c) => setState(() => _country = c)),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => busy ? null : _submit(),
          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : _submit, child: Padding(padding: const EdgeInsets.all(14), child: Text(busy ? 'Please wait…' : 'Sign in'))),
        const SizedBox(height: 8),
        Text('Forgot your password? Ask the benj team to reset it.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...messages(),
      ],
    );
  }
}

/// Email and password, with a back button to the sign-in choices.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> with _FormRunner {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _business = TextEditingController();
  bool _signUp = false, _consent = false;

  void _submit() {
    final email = _email.text.trim(), pw = _password.text;
    if (_signUp && _business.text.trim().isEmpty) {
      setState(() => error = 'Type your business name.');
      return;
    }
    if (_signUp && !_consent) {
      setState(() => error = 'Please tick the box so benj can keep your stock records.');
      return;
    }
    if (_signUp) PendingShop.set(_business.text.trim());
    run(() async {
      try {
        await (_signUp ? _auth.signUpEmail(email, pw) : _auth.signInEmail(email, pw));
      } catch (_) {
        PendingShop.clear();
        rethrow;
      }
    }, AuthService.friendly, signsIn: true);
  }

  void _forgot() {
    if (_email.text.trim().isEmpty) {
      setState(() => error = 'Type your email first, then tap Forgot password.');
      return;
    }
    run(() async {
      await _auth.resetPassword(_email.text.trim());
      if (mounted) setState(() => info = 'Check your email for a reset link.');
    }, AuthService.friendly);
  }

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.all(14);
    return _FormPage(
      title: _signUp ? 'Create your account' : 'Sign in with email',
      busy: busy,
      oops: oops,
      children: [
        if (_signUp) ...[
          TextField(
            controller: _business,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Business name', hintText: 'e.g. Ama Provisions', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
          onSubmitted: (_) => busy ? null : _submit(),
          decoration: InputDecoration(labelText: 'Password', helperText: _signUp ? 'At least 6 characters' : null, border: const OutlineInputBorder()),
        ),
        if (_signUp) ConsentTick(value: _consent, onChanged: (v) => setState(() => _consent = v)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Padding(padding: pad, child: Text(busy ? 'Please wait…' : (_signUp ? 'Create account' : 'Sign in'))),
        ),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, children: [
          TextButton(
            onPressed: () => setState(() {
              _signUp = !_signUp;
              error = null;
            }),
            child: Text(_signUp ? 'I have an account' : 'New here? Create an account'),
          ),
          if (!_signUp) TextButton(onPressed: busy ? null : _forgot, child: const Text('Forgot password')),
        ]),
        ...messages(),
      ],
    );
  }
}
