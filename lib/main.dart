import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/auth_service.dart';
import 'core/repo.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'fx/fx_view.dart';
import 'screens/auth_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/shell.dart';

const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Emulator runs use a demo project so tests can never touch real shop data.
  await Firebase.initializeApp(
      options: _useEmulator
          ? const FirebaseOptions(apiKey: 'demo-key', appId: '1:000000000000:web:0', messagingSenderId: '0', projectId: 'demo-benj', authDomain: 'demo-benj.firebaseapp.com')
          : DefaultFirebaseOptions.currentPlatform);
  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8087);
  }
  // Offline first: logs are written to the phone's cache and sync when the network returns.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  runApp(const BenjApp());
}

class BenjApp extends StatelessWidget {
  const BenjApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'benj',
        debugShowCheckedModeBanner: false,
        theme: B.theme(),
        home: const _Gate(),
      );
}

/// Signed out -> login. Signed in with no shop -> setup. Otherwise -> the app.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _auth = AuthService();
  ShopRepo? _repo;
  String? _uid;
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _introDone = true);
    });
  }

  ShopRepo _repoFor(String uid) {
    if (_uid != uid) {
      _repo?.dispose();
      _uid = uid;
      _repo = ShopRepo(uid);
    }
    return _repo!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.changes,
      builder: (context, snap) {
        Widget child;
        if (!_introDone || snap.connectionState == ConnectionState.waiting) {
          child = const _NameReveal(key: ValueKey('intro'));
        } else if (snap.data == null) {
          child = const AuthScreen(key: ValueKey('auth'));
        } else {
          final repo = _repoFor(snap.data!.uid);
          child = ListenableBuilder(
            key: const ValueKey('app'),
            listenable: repo,
            builder: (context, _) {
              if (!repo.shopLoaded) return const _LoadingShop();
              if (repo.shop == null) return SetupScreen(repo: repo, user: snap.data!);
              return Shell(repo: repo);
            },
          );
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: child);
      },
    );
  }
}

/// The name, poured in glass, right after the liquid-metal boot logo.
class _NameReveal extends StatelessWidget {
  const _NameReveal({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            height: 200,
            child: FxView(kind: 'glyph', config: const {'look': 'glass'}, fallback: Center(child: Text('benj', style: B.display(72)))),
          ),
        ),
      );
}

/// Points falling into the benj mark: scattered records becoming one clear answer.
class _LoadingShop extends StatelessWidget {
  const _LoadingShop();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: FxView(kind: 'quantum', fallback: Center(child: CircularProgressIndicator()))),
          Positioned(left: 0, right: 0, bottom: 64, child: Text('Opening your shop…', textAlign: TextAlign.center, style: B.body(15, color: B.mute))),
          if (kDebugMode) const SizedBox.shrink(),
        ]),
      );
}
