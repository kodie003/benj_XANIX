import 'models.dart';

/// Turns "sold five small rice and two noodles" into rows the owner can confirm.
/// Deliberately simple and explainable: number words, a verb, and the closest product.
class ParsedEntry {
  ParsedEntry(this.product, this.quantity, this.type);
  final Product product;
  final double quantity;
  final String type; // sale | restock | count
}

const _units = {
  'a': 1, 'an': 1, 'one': 1, 'two': 2, 'to': 2, 'too': 2, 'three': 3, 'four': 4, 'for': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
};
const _saleWords = {'sold', 'sell', 'sale', 'sales', 'selling', 'gone', 'took'};
const _restockWords = {'bought', 'buy', 'received', 'restock', 'restocked', 'got', 'added', 'delivered'};
const _countWords = {'left', 'remaining', 'remain', 'have', 'count', 'counted', 'there'};
const _skip = {'of', 'the', 'and', 'some', 'we', 'i', 'today', 'just', 'are', 'is', 'bags', 'bag', 'packs', 'pack', 'cartons', 'carton', 'crates', 'crate', 'bottles', 'bottle', 'tins', 'tin', 'pieces', 'piece', 'kilo', 'kilos', 'kg'};

List<String> _tokens(String s) => s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9. ]"), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

double? _numberAt(List<String> t, int i) {
  final d = double.tryParse(t[i]);
  if (d != null) return d;
  final u = _units[t[i]];
  if (u == null) return null;
  // "twenty five"
  if (u >= 20 && i + 1 < t.length && (_units[t[i + 1]] ?? 99) < 10) return (u + _units[t[i + 1]]!).toDouble();
  return u.toDouble();
}

/// "a kilo" style sizes are part of a product, not a quantity: "rice 4.5 kg".
bool _isSizeNumber(List<String> t, int i) => i + 1 < t.length && (t[i + 1] == 'kg' || t[i + 1] == 'kilo' || t[i + 1] == 'kilos' || t[i + 1] == 'litre' || t[i + 1] == 'l');

/// The product whose words best match what was said. "small" and "big" pick the
/// smallest or largest variant, because that is how owners actually talk.
Product? matchProduct(String words, List<Product> products) {
  final said = _tokens(words).toSet();
  Product? best;
  var score = 0.0;
  for (final p in products) {
    final name = _tokens(p.name);
    final size = _tokens(p.size);
    var s = 0.0;
    for (final w in name) {
      if (said.contains(w) || said.contains('${w}s') || (w.endsWith('s') && said.contains(w.substring(0, w.length - 1)))) s += 2;
    }
    if (s == 0) continue;
    for (final w in size) {
      if (said.contains(w)) s += 1.5;
    }
    if (s > score) {
      score = s;
      best = p;
    }
  }
  if (best == null) return null;
  final variants = products.where((p) => p.group == best!.group).toList();
  if (variants.length > 1) {
    final sized = variants.map((p) => (p, double.tryParse(RegExp(r'[\d.]+').stringMatch(p.size) ?? '') ?? 0)).toList()..sort((a, b) => a.$2.compareTo(b.$2));
    if (said.contains('small') || said.contains('smaller') || said.contains('little')) return sized.first.$1;
    if (said.contains('big') || said.contains('large') || said.contains('bigger')) return sized.last.$1;
  }
  return best;
}

List<ParsedEntry> parseSpeech(String text, List<Product> products) {
  final t = _tokens(text);
  final out = <ParsedEntry>[];
  var verb = 'sale'; // "five noodles" on its own most likely means sold.
  for (final w in t) {
    if (_restockWords.contains(w)) {
      verb = 'restock';
      break;
    }
    if (_saleWords.contains(w)) break;
  }
  if (!t.any(_saleWords.contains) && !t.any(_restockWords.contains) && t.any(_countWords.contains)) verb = 'count';

  // Find every quantity, and read the words after it (or before, for "rice five") as its product.
  final numbers = <int>[];
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (_units[t[i - 1]] ?? 0) >= 20 && (_units[t[i]] ?? 99) < 10) continue; // "five" in "twenty five"
    if (_numberAt(t, i) != null && !_isSizeNumber(t, i) && t[i] != 'a' && t[i] != 'an' && t[i] != 'to' && t[i] != 'too' && t[i] != 'for') numbers.add(i);
  }
  for (var n = 0; n < numbers.length; n++) {
    final i = numbers[n];
    final q = _numberAt(t, i)!;
    final end = n + 1 < numbers.length ? numbers[n + 1] : t.length;
    final compound = (_units[t[i]] ?? 0) >= 20 && i + 1 < t.length && (_units[t[i + 1]] ?? 99) < 10;
    var phrase = t.sublist(compound ? i + 2 : i + 1, end).where((w) => !_skip.contains(w) || w == 'kg').join(' ');
    var product = matchProduct(phrase, products);
    if (product == null && i > 0) {
      final start = n > 0 ? numbers[n - 1] + 1 : 0;
      phrase = t.sublist(start, i).join(' ');
      product = matchProduct(phrase, products);
    }
    if (product != null) out.add(ParsedEntry(product, q, verb));
  }
  return out;
}
