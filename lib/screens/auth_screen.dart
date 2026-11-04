import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/theme.dart';
import '../fx/fx_view.dart';

/// Phone first, because the owners we met live on their phones; Google and email
/// sit one tap away. If a route fails, the message says what to do next.
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
  final _mascot = FxController();
  _Route _route = _Route.phone;
  bool _signUp = false, _busy = false;
  String? _error, _sentTo, _info;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    _mascot.send({'state': 'think'});
    try {
      await job();
      _mascot.send({'state': 'idle'});
    } catch (e) {
      _mascot.send({'state': 'worried', 'ms': 2200});
      _mascot.send({'state': 'idle'});
      if (mounted) setState(() => _error = AuthService.friendly(e));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 120, child: FxView(kind: 'glyph', config: const {'look': 'glass'}, fallback: Center(child: Text('benj', style: B.display(52))))),
                      SizedBox(height: 200, child: Mascot(state: 'wave', framing: 'full', controller: _mascot)),
                      const SizedBox(height: 10),
                      Text(
                        _route == _Route.code ? 'Enter your code' : (_route == _Route.email ? (_signUp ? 'Create your account' : 'Welcome back') : 'Know what to buy before you run out'),
                        textAlign: TextAlign.center,
                        style: B.display(25),
                      ),
                      const SizedBox(height: 18),
                      ..._form(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: B.body(14, color: B.coral, w: FontWeight.w600)),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 12),
                        Text(_info!, textAlign: TextAlign.center, style: B.body(14, color: B.teal, w: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form() {
    switch (_route) {
      case _Route.phone:
        return [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            style: B.body(18, w: FontWeight.w600),
            decoration: const InputDecoration(labelText: 'Phone number', hintText: '024 123 4567', prefixText: '+233  '),
            onSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _sendCode, child: Text(_busy ? 'Sending…' : 'Text me a code')),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run(_auth.signInWithGoogle),
                child: const Text('Google'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: _busy ? null : () => setState(() { _route = _Route.email; _error = null; }), child: const Text('Email'))),
          ]),
        ];
      case _Route.code:
        return [
          Text('We texted a 6-digit code to $_sentTo', textAlign: TextAlign.center, style: B.body(14.5, color: B.mute)),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: B.mono(26, color: B.text, spacing: 8),
            decoration: const InputDecoration(counterText: '', hintText: '······'),
            onChanged: (v) {
              if (v.length == 6 && !_busy) _run(() => _auth.confirmCode(v));
            },
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : () => _run(() => _auth.confirmCode(_code.text.trim())), child: Text(_busy ? 'Checking…' : 'Continue')),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Send it again')),
            TextButton(onPressed: () => setState(() { _route = _Route.phone; _error = null; _code.clear(); }), child: const Text('Change number')),
          ]),
        ];
      case _Route.email:
        return [
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], style: B.body(16), decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], style: B.body(16), decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _run(() => _signUp ? _auth.signUpEmail(_email.text.trim(), _password.text) : _auth.signInEmail(_email.text.trim(), _password.text)),
            child: Text(_signUp ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 6),
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
            TextButton(onPressed: () => setState(() { _route = _Route.phone; _error = null; }), child: const Text('Use phone instead')),
          ]),
        ];
    }
  }
}
