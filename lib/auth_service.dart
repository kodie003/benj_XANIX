import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Email and password, Google, and phone. Web and Android differ under the hood:
///  * Web: Firebase runs an invisible reCAPTCHA, then Google texts the code to the phone.
///  * Android: Firebase checks the app is genuine, texts the code, and may read it
///    automatically, so the owner sometimes never has to type it.
/// The business name typed while creating an account, held until the account exists
/// and the shop can be saved under it.
class PendingShop {
  static ({String name, String phone})? _value;
  static void set(String name, {String phone = ''}) => _value = (name: name, phone: phone);
  static ({String name, String phone})? take() {
    final v = _value;
    _value = null;
    return v;
  }

  static void clear() => _value = null;
}

/// A failure from benj's account service, with a code [AuthService.friendly] explains.
class BenjAuthError implements Exception {
  BenjAuthError(this.code);
  final String code; // business-taken, phone-taken, wrong, service, too-many-requests
  @override
  String toString() => 'BenjAuthError($code)';
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  static bool _googleReady = false;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get user => _auth.currentUser;

  // ---- benj accounts: sign in with business name, phone or email (api/accounts.py) ----
  static const _base = String.fromEnvironment('API_BASE');
  static Uri get _accountsUrl => _base.isEmpty ? Uri.base.resolve('/api/accounts') : Uri.parse('$_base/api/accounts');

  static Future<Map<String, dynamic>> _accounts(Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await http.post(_accountsUrl, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw BenjAuthError('service');
    }
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return data;
    if (res.statusCode == 409) throw BenjAuthError('${data['kind']}-taken');
    if (res.statusCode == 401) throw BenjAuthError('wrong');
    if (res.statusCode == 429) throw BenjAuthError('too-many-requests');
    throw BenjAuthError('service');
  }

  static bool looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

  /// Create a benj account. The login is the email if one is given, otherwise the phone.
  /// Business name (and phone) must not belong to another shop.
  Future<void> createBenjAccount({required String business, String? phone, String? email, required String password}) async {
    final free = await _accounts({'action': 'available', 'business': business, 'phone': ?phone});
    if (free['business'] == false) throw BenjAuthError('business-taken');
    if (phone != null && free['phone'] == false) throw BenjAuthError('phone-taken');
    final login = email ?? phoneLogin(phone!);
    final cred = await _auth.createUserWithEmailAndPassword(email: login, password: password);
    try {
      await registerNames(business: business, phone: phone, email: email);
    } catch (e) {
      // Someone took the name at the same moment: undo, so nothing is half-made.
      await cred.user?.delete();
      rethrow;
    }
  }

  /// Records this account's business name / phone / email so it can sign in with any.
  Future<void> registerNames({String? business, String? phone, String? email}) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw BenjAuthError('service');
    await _accounts({'action': 'register', 'idToken': token, 'business': ?business, 'phone': ?phone, 'email': ?email});
  }

  /// Sign in with a business name, phone number or email, and the password.
  Future<void> signInAny(String identifier, String password) async {
    final id = identifier.trim();
    if (looksLikeEmail(id)) {
      try {
        await _auth.signInWithEmailAndPassword(email: id, password: password);
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'invalid-credential' && e.code != 'user-not-found' && e.code != 'wrong-password') rethrow;
      }
    }
    final found = await _accounts({'action': 'resolve', 'identifier': id, 'password': password});
    await _auth.signInWithEmailAndPassword(email: found['login'] as String, password: password);
  }

  /// Sends Firebase's reset link to the account's email, if it has one.
  Future<void> requestReset(String identifier) => _accounts({'action': 'reset', 'identifier': identifier.trim()});

  /// Removes this account from the sign-in index (before deleting the account).
  Future<void> unregister() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token != null) await _accounts({'action': 'unregister', 'idToken': token});
  }

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

  /// [e164] comes from the phone field, e.g. +233241234567 (see core/countries.dart).
  Future<void> signInPhonePassword(String e164, String password) =>
      _auth.signInWithEmailAndPassword(email: phoneLogin(e164), password: password);

  Future<void> signUpPhonePassword(String e164, String password) =>
      _auth.createUserWithEmailAndPassword(email: phoneLogin(e164), password: password);

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

  /// Firebase only lets an account be deleted soon after signing in.
  bool get signedInRecently {
    final at = _auth.currentUser?.metadata.lastSignInTime;
    return at != null && DateTime.now().difference(at) < const Duration(minutes: 4);
  }

  Future<void> deleteAccount() async {
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    await _auth.currentUser?.delete();
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// Plain English for every failure an owner can actually hit.
  static String friendly(Object e) {
    if (e is BenjAuthError) {
      return switch (e.code) {
        'business-taken' => 'That business name is already on benj. Add your area, like "Ama Provisions Berekuso".',
        'phone-taken' => 'That phone number already has a benj account. Try signing in.',
        'email-taken' => 'That email already has a benj account. Try signing in.',
        'wrong' => "That name, number, email or password isn't right.",
        'too-many-requests' => 'Too many tries. Please wait a little and try again.',
        _ => "We couldn't reach benj. Check your connection and try again.",
      };
    }
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
          return "That name, number, email or password isn't right.";
        case 'email-already-in-use':
          return 'That email already has a benj account. Try signing in.';
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
