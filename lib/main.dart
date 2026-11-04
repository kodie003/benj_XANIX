import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'brand.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'poddy/poddy.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/items.dart';
import 'screens/record.dart';
import 'screens/setup.dart';

/// `flutter build web --dart-define=USE_EMULATOR=true` signs in against the local
/// Firebase emulators (demo project), so tests never touch real accounts.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: _useEmulator
        ? const FirebaseOptions(apiKey: 'demo-key', appId: '1:000000000000:web:0', messagingSenderId: '0', projectId: 'demo-benj', authDomain: 'demo-benj.firebaseapp.com')
        : DefaultFirebaseOptions.currentPlatform,
  );
  if (_useEmulator) await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  runApp(const BenjApp());
}

class BenjApp extends StatelessWidget {
  const BenjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'benj',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: benjGreen),
      home: const _Gate(),
    );
  }
}

/// Signed out -> sign in. Signed in -> that account's own records.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _auth = AuthService();
  AppState? _state;

  AppState _stateFor(String uid) {
    if (_state?.uid != uid) {
      _state?.dispose();
      _state = AppState(uid)..load();
    }
    return _state!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const BenjLoading();
        }
        final user = snap.data;
        if (user == null) return const AuthScreen();
        final state = _stateFor(user.uid);
        return ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            if (!state.loaded) return const BenjLoading();
            return state.isSetUp ? Shell(state: state, auth: _auth) : SetupScreen(state: state, onSignOut: _auth.signOut);
          },
        );
      },
    );
  }
}

/// Three tabs - the whole product loop: record -> see actions -> act.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state, required this.auth});
  final AppState state;
  final AuthService auth;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  void _menu(String v) {
    final state = widget.state;
    switch (v) {
      case 'credits':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Credits'),
            content: const Text(poddyCredit),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      case 'reset':
        state.reset();
      case 'signout':
        widget.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final who = widget.auth.user;
    final account = who?.email ?? who?.phoneNumber ?? '';
    final pages = [HomeScreen(state: state), RecordScreen(state: state), ItemsScreen(state: state)];
    return Scaffold(
      appBar: AppBar(
        title: const BenjLogo(height: 26),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Update my actions', onPressed: state.refresh),
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              if (account.isNotEmpty) PopupMenuItem(enabled: false, child: Text('Signed in as $account')),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
              const PopupMenuItem(value: 'credits', child: Text('Credits')),
              const PopupMenuItem(value: 'reset', child: Text('Start over (deletes records)')),
            ],
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.lightbulb_outline), label: 'This week'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Record'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Items'),
        ],
      ),
    );
  }
}
