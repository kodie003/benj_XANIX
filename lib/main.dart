import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'brand.dart';
import 'core/models.dart';
import 'core/repo.dart';
import 'firebase_options.dart';
import 'screens/auth.dart';
import 'screens/name_shop.dart';
import 'screens/shell.dart';

/// `flutter build web --dart-define=USE_EMULATOR=true` uses the local Firebase emulators
/// (demo project), so tests never touch real accounts or shops.
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: _useEmulator
        ? const FirebaseOptions(apiKey: 'demo-key', appId: '1:000000000000:web:0', messagingSenderId: '0', projectId: 'demo-benj', authDomain: 'demo-benj.firebaseapp.com')
        : DefaultFirebaseOptions.currentPlatform,
  );
  if (_useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8087);
  }
  // Offline first (PRD section 7): every log lands on the phone and syncs when the network returns.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
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

/// Signed out -> sign in. Signed in with no shop yet -> name it. Otherwise -> the app.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _auth = AuthService();
  ShopRepo? _repo;

  ShopRepo _repoFor(String uid) {
    if (_repo?.uid != uid) {
      _repo?.dispose();
      _repo = ShopRepo(uid);
    }
    return _repo!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const BenjLoading();
        final user = snap.data;
        if (user == null) {
          _repo?.dispose();
          _repo = null;
          return const AuthScreen();
        }
        final repo = _repoFor(user.uid);
        return ListenableBuilder(
          listenable: repo,
          builder: (context, _) {
            if (!repo.shopLoaded) return const BenjLoading();
            if (repo.shop == null) {
              // Just created an account with a business name: save the shop, then go in.
              final pending = PendingShop.take();
              if (pending != null) {
                repo.saveShop(Shop(name: pending.name, ownerPhone: pending.phone));
                return const BenjLoading();
              }
              return NameShopScreen(repo: repo, user: user, onSignOut: _auth.signOut);
            }
            return Shell(repo: repo, auth: _auth);
          },
        );
      },
    );
  }
}
