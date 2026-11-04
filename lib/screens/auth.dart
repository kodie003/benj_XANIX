import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../poddy/poddy.dart';
import 'name_shop.dart' show ConsentTick;

/// Sign-in choices: a benj account (phone number + password), Google, or email.
/// Phone/SMS codes are paused until the team decides how to pay for SMS; the
/// code for them is still in AuthService.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  bool _busy = false;
  String? _error;

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendly(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const pad = EdgeInsets.all(14);
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: BenjLogo(height: 64)),
                  const SizedBox(height: 14),
                  Text('Know what to do with your shop this week.', textAlign: TextAlign.center, style: text.bodyLarge),
                  const SizedBox(height: 8),
                  // First hello: Poddy hovers here, like on day one, with a short greeting.
                  const SizedBox(height: 170, child: PoddyView(mood: 'hello')),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                      ),
                      child: Text("Hi! I'm Poddy. Let's get you in.", style: text.titleSmall),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _open(const PhoneAccountScreen()),
                    icon: const Icon(Icons.phone_android),
                    label: const Padding(padding: pad, child: Text('Sign in with phone number')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Padding(padding: pad, child: Text(_busy ? 'Opening Google…' : 'Continue with Google')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _open(const EmailSignInScreen()),
                    icon: const Icon(Icons.mail_outline),
                    label: const Padding(padding: pad, child: Text('Continue with email')),
                  ),
                  const SizedBox(height: 14),
                  Text('New to benj? Tap "Sign in with phone number" to create your account.',
                      textAlign: TextAlign.center, style: text.bodySmall),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
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

/// The benj account: phone number and password. No SMS, so nothing to pay for.
class PhoneAccountScreen extends StatefulWidget {
  const PhoneAccountScreen({super.key});

  @override
  State<PhoneAccountScreen> createState() => _PhoneAccountScreenState();
}

class _PhoneAccountScreenState extends State<PhoneAccountScreen> with _FormRunner {
  final _auth = AuthService();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _business = TextEditingController();
  bool _create = false, _consent = false;

  void _submit() {
    final number = AuthService.normalisePhone(_phone.text);
    if (_create && _business.text.trim().isEmpty) {
      setState(() => error = "Type your business name.");
      return;
    }
    if (!AuthService.looksValidPhone(number)) {
      setState(() => error = 'Enter your phone number, like 024 123 4567.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => error = 'Use a password of at least 6 characters.');
      return;
    }
    if (_create && _password.text != _confirm.text) {
      setState(() => error = "The two passwords don't match.");
      return;
    }
    if (_create && !_consent) {
      setState(() => error = 'Please tick the box so benj can keep your stock records.');
      return;
    }
    if (_create) PendingShop.set(_business.text.trim(), phone: number);
    run(
      () async {
        try {
          await (_create ? _auth.signUpPhonePassword(_phone.text, _password.text) : _auth.signInPhonePassword(_phone.text, _password.text));
        } catch (_) {
          PendingShop.clear();
          rethrow;
        }
      },
      AuthService.friendlyPhone,
      signsIn: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.all(14);
    return _FormPage(
      title: _create ? 'Create a benj account' : 'Sign in with phone',
      busy: busy,
      oops: oops,
      children: [
        if (_create) ...[
          TextField(
            controller: _business,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Business name', hintText: 'e.g. Ama Provisions', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Phone number', hintText: '024 123 4567', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: [_create ? AutofillHints.newPassword : AutofillHints.password],
          textInputAction: _create ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) => _create || busy ? null : _submit(),
          decoration: InputDecoration(labelText: 'Password', helperText: _create ? 'At least 6 characters' : null, border: const OutlineInputBorder()),
        ),
        if (_create) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => busy ? null : _submit(),
            decoration: const InputDecoration(labelText: 'Type the password again', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 4),
          ConsentTick(value: _consent, onChanged: (v) => setState(() => _consent = v)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Padding(padding: pad, child: Text(busy ? 'Please wait…' : (_create ? 'Create my account' : 'Sign in'))),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() {
            _create = !_create;
            error = null;
          }),
          child: Text(_create ? 'I already have an account' : 'New here? Create a benj account'),
        ),
        if (!_create)
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
