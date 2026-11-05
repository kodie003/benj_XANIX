import 'package:cloud_firestore/cloud_firestore.dart';

/// The data model from PRD section 9. Everything sits under shops/{uid}, so each
/// owner's records are private to them.
class Shop {
  Shop({required this.name, this.location = '', this.ownerPhone = '', this.ownerName = '', this.restockDay, this.consentAt});

  final String name, location, ownerPhone, ownerName;
  final int? restockDay; // 1 Monday ... 7 Sunday
  final DateTime? consentAt;

  factory Shop.fromMap(Map<String, dynamic> m) => Shop(
        name: m['name'] ?? '',
        location: m['location'] ?? '',
        ownerPhone: m['ownerPhone'] ?? '',
        ownerName: m['ownerName'] ?? '',
        restockDay: m['restockDay'],
        consentAt: (m['consentAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'location': location,
        'ownerPhone': ownerPhone,
        'ownerName': ownerName,
        'restockDay': restockDay,
        'consentAt': consentAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(consentAt!),
      };
}

/// How products are counted. "olonka" is the Ghanaian tin measure for grains (rice, gari,
/// beans); it has no standard size, so benj counts olonkas and never converts to kilos.
const kUnits = ['bag', 'pack', 'carton', 'crate', 'bottle', 'tin', 'piece', 'olonka'];

/// Shown for products with no category. Never stored: those keep an empty category.
const kNotSorted = 'Not sorted';
const kCategoryMax = 40;

/// "  toiletries " -> "Toiletries".
String cleanCategory(String raw) {
  final s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return '';
  final cut = s.length > kCategoryMax ? s.substring(0, kCategoryMax).trim() : s;
  return cut[0].toUpperCase() + cut.substring(1);
}

/// Tidies a name and, if the owner already has it in other capitals, uses theirs.
String matchCategory(String raw, Iterable<String> existing) {
  final name = cleanCategory(raw);
  for (final e in existing) {
    if (e.toLowerCase() == name.toLowerCase()) return e;
  }
  return name;
}

/// Products under their categories, A to Z, with the unsorted ones last.
List<(String, List<Product>)> groupByCategory(List<Product> products, {String Function(Product)? of}) {
  final groups = <String, List<Product>>{};
  for (final p in products) {
    (groups[(of?.call(p) ?? p.category)] ??= []).add(p);
  }
  final names = groups.keys.where((n) => n.isNotEmpty).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [
    for (final n in names) (n, groups[n]!),
    if (groups[''] != null) (kNotSorted, groups['']!),
  ];
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.unit,
    this.size = '',
    this.costPrice,
    this.sellPrice,
    this.warningLevel,
    this.category = '',
  });

  final String id, name, unit, size;

  /// The owner's umbrella for this product, such as Toiletries. Empty means not sorted yet.
  final String category;
  final double? costPrice, sellPrice;

  /// null means "accept benj's suggestion" (F4).
  final double? warningLevel;

  String get label => size.isEmpty ? name : '$name $size';

  /// What counts as "the same product": name and size, ignoring capitals and spaces,
  /// so "Rice 1 kg" and "rice 1kg" match.
  static String keyOf(String name, String size) => '$name $size'
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'(\d) (kg|g|ml|l)\b'), (m) => '${m[1]}${m[2]}')
      .trim();

  String get key => keyOf(name, size);

  /// Variants of a product (rice 1 kg, rice 4.5 kg) share a group.
  String get group => name.trim().toLowerCase();

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Product(
      id: d.id,
      name: m['name'] ?? '',
      unit: m['unit'] ?? 'piece',
      size: m['size'] ?? '',
      costPrice: (m['costPrice'] as num?)?.toDouble(),
      sellPrice: (m['sellPrice'] as num?)?.toDouble(),
      warningLevel: (m['warningLevel'] as num?)?.toDouble(),
      category: m['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit,
        'size': size,
        'costPrice': costPrice,
        'sellPrice': sellPrice,
        'warningLevel': warningLevel,
        'category': category,
      };

  String plural(num n) {
    if (n == 1) return unit;
    return kUnits.contains(unit) ? '${unit}s' : unit;
  }
}

/// [method] and [secondsTaken] exist to measure the riskiest assumption: logging.
class StockLog {
  StockLog({
    this.id = '',
    required this.product,
    required this.at,
    required this.type,
    required this.quantity,
    this.unitPrice,
    this.method = 'tap',
    this.secondsTaken,
  });

  final String id, product, type, method; // type: count | sale | restock
  final DateTime at;
  final double quantity;
  final double? unitPrice;
  final int? secondsTaken;

  factory StockLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return StockLog(
      id: d.id,
      product: m['product'] ?? '',
      at: (m['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: m['type'] ?? 'sale',
      quantity: (m['quantity'] as num? ?? 0).toDouble(),
      unitPrice: (m['unitPrice'] as num?)?.toDouble(),
      method: m['method'] ?? 'tap',
      secondsTaken: m['secondsTaken'],
    );
  }

  Map<String, dynamic> toMap() => {
        'product': product,
        'at': Timestamp.fromDate(at),
        'type': type,
        'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        'method': method,
        if (secondsTaken != null) 'secondsTaken': secondsTaken,
      };

  Map<String, dynamic> toEngine() => {'product': product, 'at': at.toIso8601String(), 'type': type, 'quantity': quantity};
}

class ShopEvent {
  ShopEvent({this.id = '', required this.name, required this.start, required this.end, required this.factor});

  final String id, name;
  final DateTime start, end;
  final double factor; // 0.6 = 40% fewer customers, 1.3 = 30% more

  factory ShopEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ShopEvent(
      id: d.id,
      name: m['name'] ?? '',
      start: (m['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (m['end'] as Timestamp?)?.toDate() ?? DateTime.now(),
      factor: (m['factor'] as num? ?? 1).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'start': Timestamp.fromDate(start), 'end': Timestamp.fromDate(end), 'factor': factor};
}
