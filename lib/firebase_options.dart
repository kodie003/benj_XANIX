// Firebase config for project benj-27c66 (from `firebase apps:sdkconfig`).
// These values identify the project; they are not secrets. Data is protected by
// firestore.rules and Firebase Auth.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('benj is set up for web and Android only.');
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyB-JRfxfNRUWOiDPx6iiDcBv9xpy-h6He8',
    appId: '1:855341144437:web:367c750b76a7f48b875b3c',
    messagingSenderId: '855341144437',
    projectId: 'benj-27c66',
    authDomain: 'benj-27c66.firebaseapp.com',
    storageBucket: 'benj-27c66.firebasestorage.app',
    measurementId: 'G-FQ58431XLV',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyCY1Jgd--lCE-8J6qARk5HGQc51XPHmPYE',
    appId: '1:855341144437:android:f6d85a3dca5b218a875b3c',
    messagingSenderId: '855341144437',
    projectId: 'benj-27c66',
    storageBucket: 'benj-27c66.firebasestorage.app',
  );
}
