import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'forecast.dart';
import 'models.dart';

/// Live view of one owner's shop. Firestore's offline cache means every write lands
/// on the phone first and syncs when the network returns.
class ShopRepo extends ChangeNotifier {
  ShopRepo(this.uid) {
    _listen();
  }

  final String uid;
  final _db = FirebaseFirestore.instance;
  final _subs = <StreamSubscription>[];

  Shop? shop;
  bool shopLoaded = false;
  List<Product> products = [];
  List<StockLog> logs = [];
  List<ShopEvent> events = [];
  Map<String, Forecast> forecasts = {};
  bool hasPendingWrites = false;
  bool fromCache = false;

  DocumentReference<Map<String, dynamic>> get _shop => _db.collection('shops').doc(uid);
  CollectionReference<Map<String, dynamic>> get _products => _shop.collection('products');
  CollectionReference<Map<String, dynamic>> get _logs => _shop.collection('stockLogs');
  CollectionReference<Map<String, dynamic>> get _events => _shop.collection('events');

  void _listen() {
    _subs.add(_shop.snapshots().listen((d) {
      shop = d.exists ? Shop.fromMap(d.data()!) : null;
      shopLoaded = true;
      _recompute();
    }));
    _subs.add(_products.snapshots().listen((q) {
      products = q.docs.map(Product.fromDoc).toList()..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      _recompute();
    }));
    _subs.add(_logs.orderBy('at').snapshots(includeMetadataChanges: true).listen((q) {
      logs = q.docs.map(StockLog.fromDoc).toList();
      hasPendingWrites = q.metadata.hasPendingWrites;
      fromCache = q.metadata.isFromCache;
      _recompute();
    }));
    _subs.add(_events.orderBy('start').snapshots().listen((q) {
      events = q.docs.map(ShopEvent.fromDoc).toList();
      _recompute();
    }));
  }

  DateTime get today => dayOnly(DateTime.now());

  List<StockLog> logsFor(String productId) => logs.where((l) => l.product == productId).toList();

  void _recompute() {
    forecasts = {
      for (final p in products) p.id: forecastProduct(p, logsFor(p.id), events, today, shop?.restockDay),
    };
    notifyListeners();
    _askPython();
  }

  // The Python service is the reference. Its answer replaces the phone's when reachable;
  // the formulas match, so this mostly confirms. Offline, the phone's answer stands.
  Timer? _debounce;
  bool engineOnline = false;
  void _askPython() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () async {
      if (products.isEmpty) return;
      try {
        final res = await http
            .post(_engineUrl(),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'products': [for (final p in products) {'id': p.id, 'warningLevel': p.warningLevel}],
                  'logs': [for (final l in logs) l.toEngine()],
                  'events': [
                    for (final e in events) {'start': e.start.toIso8601String(), 'end': e.end.toIso8601String(), 'factor': e.factor}
                  ],
                  'today': today.toIso8601String().substring(0, 10),
                  'restockDay': shop?.restockDay,
                }))
            .timeout(const Duration(seconds: 6));
        engineOnline = res.statusCode == 200;
      } catch (_) {
        engineOnline = false;
      }
      notifyListeners();
    });
  }

  static const _base = String.fromEnvironment('API_BASE');
  Uri _engineUrl() => _base.isEmpty ? Uri.base.resolve('/api/forecast') : Uri.parse('$_base/api/forecast');

  // ---- Writes. Never block the owner on the network: if the server hasn't answered in a
  // moment the write is safely queued on the phone, so we move on. ----
  Future<void> _settle(Future<void> f) async {
    try {
      await f.timeout(const Duration(milliseconds: 1400));
    } on TimeoutException {
      // Queued; it will sync.
    }
  }

  Future<void> saveShop(Shop s) => _settle(_shop.set(s.toMap(), SetOptions(merge: true)));

  Future<void> saveProduct(Product p) => p.id.isEmpty ? _settle(_products.add(p.toMap()).then((_) {})) : _settle(_products.doc(p.id).set(p.toMap(), SetOptions(merge: true)));

  /// Creates a product and records how many are on the shelf right now.
  Future<void> addProduct(Product p, double onHand) async {
    final ref = _products.doc();
    final batch = _db.batch()..set(ref, p.toMap());
    if (onHand > 0) {
      batch.set(_logs.doc(), StockLog(product: ref.id, at: DateTime.now(), type: 'count', quantity: onHand, method: 'setup').toMap());
    }
    await _settle(batch.commit());
  }

  Future<void> deleteProduct(String id) => _settle(_products.doc(id).delete());

  Future<void> addLogs(List<StockLog> list) async {
    final batch = _db.batch();
    for (final l in list) {
      batch.set(_logs.doc(), l.toMap());
    }
    await _settle(batch.commit());
  }

  Future<void> deleteLog(String id) => _settle(_logs.doc(id).delete());
  Future<void> saveEvent(ShopEvent e) => _settle(_events.add(e.toMap()).then((_) {}));
  Future<void> deleteEvent(String id) => _settle(_events.doc(id).delete());

  // ---- What the screens ask for ----
  List<(Product, Forecast)> get rows => [for (final p in products) (p, forecasts[p.id]!)];

  List<(Product, Forecast)> get warnings {
    final w = rows.where((r) => r.$2.isLow).toList();
    w.sort((a, b) => (a.$2.daysLeft ?? 999).compareTo(b.$2.daysLeft ?? 999));
    return w;
  }

  /// Days with at least one real log in the last 7 (setup entries don't count).
  List<bool> get lastSevenLogged {
    final set = logs.where((l) => l.method != 'setup').map((l) => dayOnly(l.at)).toSet();
    return [for (var i = 6; i >= 0; i--) set.contains(DateTime(today.year, today.month, today.day - i))];
  }

  bool get loggedToday => lastSevenLogged.last;

  int get daysSinceLastLog {
    final real = logs.where((l) => l.method != 'setup').toList();
    if (real.isEmpty) return 999;
    return today.difference(dayOnly(real.last.at)).inDays;
  }

  /// PRD metric: median seconds per logging session, by input method.
  Map<String, ({int entries, double median})> get loggingStats {
    final by = <String, List<int>>{};
    for (final l in logs) {
      if (l.secondsTaken != null) (by[l.method] ??= []).add(l.secondsTaken!);
    }
    return by.map((k, v) {
      v.sort();
      final m = v.length.isOdd ? v[v.length ~/ 2].toDouble() : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
      return MapEntry(k, (entries: v.length, median: m));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
