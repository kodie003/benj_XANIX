import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../poddy/poddy.dart';

/// Phone first, because the owners we met live on their phones; Google and email are
/// one tap away. Every failure says what to do next, in plain English.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Route { phone, code, email }

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Route _route = _Route.phone;
  bool _signUp = false, _busy = false;
  String? _error, _info, _sentTo;
  int _oops = 0;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await job();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AuthService.friendly(e);
          _oops++;
        });
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _sendCode() {
    final number = AuthService.normalisePhone(_phone.text);
    if (!AuthService.looksValidPhone(number)) {
      setState(() => _error = 'Enter your phone number, like 024 123 4567.');
      return;
    }
    _run(() async {
      await _auth.sendCode(number);
      if (mounted) {
        setState(() {
          _sentTo = number;
          _route = _Route.code;
        });
      }
    });
  }

  void _go(_Route r) => setState(() {
        _route = r;
        _error = null;
        _info = null;
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = switch (_route) {
      _Route.phone => 'Sign in to benj',
      _Route.code => 'Enter your code',
      _Route.email => _signUp ? 'Create your account' : 'Sign in with email',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('benj', textAlign: TextAlign.center, style: text.displaySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Know what to do with your shop this week.', textAlign: TextAlign.center, style: text.bodyLarge),
                const SizedBox(height: 12),
                SizedBox(height: 190, child: PoddyView(mood: _busy ? 'present' : 'hello', flash: 'sad', flashTick: _oops)),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
                const SizedBox(height: 16),
                ..._form(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(_info!, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form() {
    const pad = EdgeInsets.all(14);
    switch (_route) {
      case _Route.phone:
        return [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(labelText: 'Phone number', hintText: '024 123 4567', border: OutlineInputBorder()),
            onSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _sendCode, child: Padding(padding: pad, child: Text(_busy ? 'Sending…' : 'Text me a code'))),
          const SizedBox(height: 16),
          const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or')), Expanded(child: Divider())]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(_auth.signInWithGoogle),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Padding(padding: pad, child: Text('Continue with Google')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _go(_Route.email),
            icon: const Icon(Icons.mail_outline),
            label: const Padding(padding: pad, child: Text('Use email')),
          ),
        ];
      case _Route.code:
        return [
          Text('We texted a 6-digit code to $_sentTo', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 8),
            decoration: const InputDecoration(labelText: 'Code', counterText: '', border: OutlineInputBorder()),
            onChanged: (v) {
              if (v.length == 6 && !_busy) _run(() => _auth.confirmCode(v));
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _run(() => _auth.confirmCode(_code.text.trim())),
            child: Padding(padding: pad, child: Text(_busy ? 'Checking…' : 'Continue')),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Send it again')),
            TextButton(
              onPressed: () {
                _code.clear();
                _go(_Route.phone);
              },
              child: const Text('Change number'),
            ),
          ]),
        ];
      case _Route.email:
        return [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() => _signUp ? _auth.signUpEmail(_email.text.trim(), _password.text) : _auth.signInEmail(_email.text.trim(), _password.text)),
            child: Padding(padding: pad, child: Text(_signUp ? 'Create account' : 'Sign in')),
          ),
          Wrap(alignment: WrapAlignment.center, children: [
            TextButton(onPressed: () => setState(() => _signUp = !_signUp), child: Text(_signUp ? 'I have an account' : 'New here? Create an account')),
            if (!_signUp)
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_email.text.trim().isEmpty) {
                          setState(() => _error = 'Type your email first, then tap Forgot password.');
                          return;
                        }
                        _run(() async {
                          await _auth.resetPassword(_email.text.trim());
                          if (mounted) setState(() => _info = 'Check your email for a reset link.');
                        });
                      },
                child: const Text('Forgot password'),
              ),
            TextButton(onPressed: () => _go(_Route.phone), child: const Text('Use phone instead')),
          ]),
        ];
    }
  }
}
