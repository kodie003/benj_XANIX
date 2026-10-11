import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// What the owner sells. Mirrors the "Item" entity in PRD section 13.
class Item {
  Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.cost,
    required this.price,
    this.reorder = 0,
    this.perishable = false,
  });

  final String id;
  String name;
  String unit;
  double cost;
  double price;
  double reorder;
  bool perishable;

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'],
        name: j['name'],
        unit: j['unit'] ?? 'piece',
        cost: (j['cost'] as num).toDouble(),
        price: (j['price'] as num).toDouble(),
        reorder: (j['reorder'] as num? ?? 0).toDouble(),
        perishable: j['perishable'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'cost': cost,
        'price': price,
        'reorder': reorder,
        'perishable': perishable,
      };
}

/// One line of the tally: opening / sale / received / waste.
/// Stock on hand is always computed from this log, never stored.
class Movement {
  Movement(this.item, this.type, this.qty, this.date, {this.cost});

  final String item;
  final String type;
  final double qty;
  final String date; // yyyy-mm-dd
  final double? cost;

  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
        j['item'],
        j['type'],
        (j['qty'] as num).toDouble(),
        j['date'],
        cost: (j['cost'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'item': item,
        'type': type,
        'qty': qty,
        'date': date,
        if (cost != null) 'cost': cost,
      };
}

String isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

/// The whole business lives on the phone (no logins, no database yet).
class AppState extends ChangeNotifier {
  static const _key = 'seeyou_v1';

  Map<String, dynamic>? business; // {name, owner, type}
  List<Item> items = [];
  List<Movement> movements = [];
  Set<String> actedOn = {}; // titles of actions the owner said they did

  Map<String, dynamic>? insights;
  String? error;
  bool loading = false;

  bool get isSetUp => business != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) _fromJson(jsonDecode(raw));
    notifyListeners();
    // ?demo in the link opens straight into the demo shop - handy for pitching.
    if (!isSetUp && Uri.base.queryParameters.containsKey('demo')) return loadDemo();
    if (isSetUp) refresh();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'business': business,
        'items': items.map((i) => i.toJson()).toList(),
        'movements': movements.map((m) => m.toJson()).toList(),
        'actedOn': actedOn.toList(),
      };

  void _fromJson(Map<String, dynamic> j) {
    business = j['business'] == null ? null : Map<String, dynamic>.from(j['business']);
    items = [for (final i in j['items'] ?? []) Item.fromJson(i)];
    movements = [for (final m in j['movements'] ?? []) Movement.fromJson(m)];
    actedOn = {...List<String>.from(j['actedOn'] ?? [])};
  }

  Future<void> setUp(Map<String, dynamic> biz, List<Item> newItems, Map<String, double> opening) async {
    business = biz;
    items = newItems;
    final today = isoDay(DateTime.now());
    movements = [
      for (final e in opening.entries)
        if (e.value > 0) Movement(e.key, 'opening', e.value, today),
    ];
    await _save();
    notifyListeners();
    refresh();
  }

  Future<void> loadDemo() async {
    loading = true;
    notifyListeners();
    try {
      _fromJson(await Api.demoData());
      await _save();
      await refresh();
    } catch (e) {
      error = 'Could not load the demo shop: $e';
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addMovements(List<Movement> list) async {
    movements.addAll(list);
    await _save();
    notifyListeners();
    refresh();
  }

  Future<void> addItem(Item item) async {
    items.add(item);
    await _save();
    notifyListeners();
  }

  Future<void> toggleActed(String title) async {
    actedOn.contains(title) ? actedOn.remove(title) : actedOn.add(title);
    await _save();
    notifyListeners();
  }

  Future<void> reset() async {
    business = null;
    items = [];
    movements = [];
    actedOn = {};
    insights = null;
    await _save();
    notifyListeners();
  }

  /// FR-C1, worked out on the phone too so it shows even offline.
  double onHand(String itemId) {
    var total = 0.0;
    for (final m in movements.where((m) => m.item == itemId)) {
      total += (m.type == 'opening' || m.type == 'received') ? m.qty : -m.qty;
    }
    return total < 0 ? 0 : total;
  }

  double recordedToday(String itemId, String type) => movements
      .where((m) => m.item == itemId && m.type == type && m.date == isoDay(DateTime.now()))
      .fold(0.0, (sum, m) => sum + m.qty);

  /// Ask the Python insight engine what this week's 3 actions are.
  Future<void> refresh() async {
    if (!isSetUp) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      insights = await Api.insights({
        'business': business,
        'items': items.map((i) => i.toJson()).toList(),
        'movements': movements.map((m) => m.toJson()).toList(),
        'today': isoDay(DateTime.now()),
      });
    } catch (e) {
      error = 'Could not reach the insight engine. Your records are saved on this phone. ($e)';
    }
    loading = false;
    notifyListeners();
  }
}
