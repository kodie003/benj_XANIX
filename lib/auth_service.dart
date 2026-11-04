import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Email and password, Google, and phone. Web and Android differ under the hood:
///  * Web: Firebase runs an invisible reCAPTCHA, then Google texts the code to the phone.
///  * Android: Firebase checks the app is genuine, texts the code, and may read it
///    automatically, so the owner sometimes never has to type it.
class AuthService {
  final _auth = FirebaseAuth.instance;
  static bool _googleReady = false;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get user => _auth.currentUser;

  // ---- Phone ----
  ConfirmationResult? _webConfirmation;
  String? _androidVerificationId;
  int? _resendToken;

  /// Ghanaian numbers are usually typed locally: 024 123 4567 becomes +233241234567.
  static String normalisePhone(String raw) {
    final d = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (d.startsWith('+')) return d;
    if (d.startsWith('00')) return '+${d.substring(2)}';
    if (d.startsWith('233')) return '+$d';
    if (d.startsWith('0')) return '+233${d.substring(1)}';
    return '+233$d';
  }

  static bool looksValidPhone(String e164) => RegExp(r'^\+\d{10,15}$').hasMatch(e164);

  /// Sends the SMS. [onAutoVerified] fires on Android when it read the code by itself.
  Future<void> sendCode(String phone, {VoidCallback? onAutoVerified}) async {
    if (kIsWeb) {
      _webConfirmation = await _auth.signInWithPhoneNumber(phone);
      return;
    }
    final done = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        onAutoVerified?.call();
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(e);
      },
      codeSent: (id, token) {
        _androidVerificationId = id;
        _resendToken = token;
        if (!done.isCompleted) done.complete();
      },
      codeAutoRetrievalTimeout: (id) => _androidVerificationId = id,
    );
    return done.future;
  }

  Future<void> confirmCode(String code) async {
    if (kIsWeb) {
      await _webConfirmation!.confirm(code);
    } else {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: _androidVerificationId!, smsCode: code));
    }
  }

  // ---- Google ----
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    if (!_googleReady) {
      await GoogleSignIn.instance.initialize();
      _googleReady = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: account.authentication.idToken));
  }

  // ---- Email ----
  Future<void> signInEmail(String email, String password) => _auth.signInWithEmailAndPassword(email: email, password: password);
  Future<void> signUpEmail(String email, String password) => _auth.createUserWithEmailAndPassword(email: email, password: password);
  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);

  // ---- benj account: phone number + password, no SMS ----
  // Firebase's password sign-in needs an email-shaped id, so the number is stored as
  // 233241234567@phone.benj.invalid. ".invalid" is reserved and can never receive mail,
  // so nothing is ever sent to it. The number itself is not verified.
  static const _phoneDomain = 'phone.benj.invalid';

  static String phoneLogin(String e164) => '${e164.replaceAll('+', '')}@$_phoneDomain';

  Future<void> signInPhonePassword(String rawPhone, String password) =>
      _auth.signInWithEmailAndPassword(email: phoneLogin(normalisePhone(rawPhone)), password: password);

  Future<void> signUpPhonePassword(String rawPhone, String password) =>
      _auth.createUserWithEmailAndPassword(email: phoneLogin(normalisePhone(rawPhone)), password: password);

  /// What to show as "Signed in as …": the phone number for benj accounts.
  static String accountLabel(User? u) {
    final email = u?.email ?? '';
    if (email.endsWith('@$_phoneDomain')) return '+${email.split('@').first}';
    return email.isNotEmpty ? email : (u?.phoneNumber ?? '');
  }

  /// Same as [friendly], but talks about the phone number instead of an email.
  static String friendlyPhone(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'That number already has a benj account. Try signing in.';
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
          return 'That number or password isn\'t right.';
        case 'invalid-email':
          return 'That number doesn\'t look right. Try it like 024 123 4567.';
      }
    }
    return friendly(e);
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// Plain English for every failure an owner can actually hit.
  static String friendly(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'That number doesn\'t look right. Try it like 024 123 4567.';
        case 'invalid-verification-code':
          return 'That code isn\'t right. Check the SMS and try again.';
        case 'code-expired':
        case 'session-expired':
          return 'That code has expired. Ask for a new one.';
        case 'too-many-requests':
          return 'Too many tries from this phone. Please wait a little and try again.';
        case 'quota-exceeded':
          return 'We\'ve reached today\'s SMS limit. Try Google or email for now.';
        case 'billing-not-enabled':
          return 'SMS login isn\'t switched on yet. Use Google or email for now.';
        case 'operation-not-allowed':
          return 'This sign-in method isn\'t switched on yet. Try another one.';
        case 'captcha-check-failed':
          return 'The security check failed. Reload the page and try again.';
        case 'unauthorized-domain':
          return 'This web address isn\'t approved for sign-in yet.';
        case 'network-request-failed':
          return 'No connection. Check your data and try again.';
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
          return 'That email or password isn\'t right.';
        case 'email-already-in-use':
          return 'That email already has an account. Try signing in.';
        case 'weak-password':
          return 'Use a password of at least 6 characters.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Google sign-in was closed before it finished.';
        case 'popup-blocked':
          return 'Your browser blocked the Google window. Allow pop-ups and try again.';
      }
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
