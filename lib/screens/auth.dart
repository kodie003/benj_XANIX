import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../poddy/poddy.dart';

/// Sign-in: one tap with Google, or email and password on its own screen.
/// (Phone/SMS sign-in is paused until the team decides how to pay for SMS;
/// the code for it is still in AuthService.)
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const pad = EdgeInsets.all(14);
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: BenjLogo(height: 64)),
                  const SizedBox(height: 14),
                  Text('Know what to do with your shop this week.', textAlign: TextAlign.center, style: text.bodyLarge),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Padding(padding: pad, child: Text(_busy ? 'Opening Google…' : 'Continue with Google')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EmailSignInScreen())),
                    icon: const Icon(Icons.mail_outline),
                    label: const Padding(padding: pad, child: Text('Continue with email')),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
          ),
        ),
        PoddyPeek(side: PeekSide.right, mood: 'hello', lines: const ["Hi! I'm Poddy.", 'Sign in to start.'], tips: poddyTips['signin']!, lift: 40),
      ]),
    );
  }
}

/// Email and password, with a back button to the sign-in choices.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false, _busy = false;
  String? _error, _info;

  Future<void> _run(Future<void> Function() job, {bool signsIn = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await job();
      // Signed in: close this screen; the app behind it has already switched.
      if (signsIn && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendly(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _submit() {
    final email = _email.text.trim(), pw = _password.text;
    _run(() => _signUp ? _auth.signUpEmail(email, pw) : _auth.signInEmail(email, pw), signsIn: true);
  }

  void _forgot() {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Type your email first, then tap Forgot password.');
      return;
    }
    _run(() async {
      await _auth.resetPassword(_email.text.trim());
      if (mounted) setState(() => _info = 'Check your email for a reset link.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const pad = EdgeInsets.all(14);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(_signUp ? 'Create your account' : 'Sign in with email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: _signUp ? 'At least 6 characters' : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Padding(padding: pad, child: Text(_busy ? 'Please wait…' : (_signUp ? 'Create account' : 'Sign in'))),
                  ),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.center, children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _signUp = !_signUp;
                        _error = null;
                      }),
                      child: Text(_signUp ? 'I have an account' : 'New here? Create an account'),
                    ),
                    if (!_signUp) TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password')),
                  ]),
                  if (_error != null) Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
                  if (_info != null) Text(_info!, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
