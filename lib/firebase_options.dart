// Web config for Firebase project benj-27c66. This file is overwritten with the real
// values once the app is registered (see "firebase apps:create"). Until then the app
// only runs against the local emulators (--dart-define=USE_EMULATOR=true).
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const currentPlatform = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-benj',
    authDomain: 'demo-benj.firebaseapp.com',
  );
}
