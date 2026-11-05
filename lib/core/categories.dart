import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import 'models.dart';

/// Poddy's suggestions: Gemini studies the product names and proposes a category for each.
/// Nothing is saved here; the owner checks, edits and saves on the categories page.
class CategorySuggester {
  static const _models = ['gemini-3.5-flash-lite', 'gemini-3.8-flash'];

  static final _schema = Schema.object(properties: {
    'assignments': Schema.array(
      items: Schema.object(properties: {
        'number': Schema.integer(description: 'The number of the product in the list.'),
        'category': Schema.string(description: 'The category, one or two plain words.'),
      }),
    ),
  });

  /// Grouped by what a product is mainly for, the rule retail classifications such as GS1 GPC
  /// use. The names are the umbrellas Ghanaian shops already talk about; they are only hints.
  static String prompt(List<Product> products, List<String> existing) => [
        'You sort the products of a small shop in Ghana into categories, so the owner can find them quickly.',
        'Give every product exactly one category, by what it is mainly used for, not by its packaging. '
            'Tinned milk and rice are both food; soap in a tin is still a toiletry.',
        if (existing.isNotEmpty) "The owner already uses these categories, so reuse them whenever they fit: ${existing.join(', ')}.",
        'Otherwise use these where they fit: Provisions (rice, oil, sugar, tinned food, milk, noodles), Drinks, Snacks, '
            'Toiletries (soap, toothpaste, pads, tissue), Household (detergent, candles, matches), Baby care, Health, Stationery, '
            'Equipment (tools, utensils, electricals).',
        'If none fits, make up a short plain name the owner would say. Use as few categories as make sense, never one per product, '
            'and never "Other" or "Miscellaneous".',
        'Products:',
        for (final (i, p) in products.indexed) '${i + 1}. ${p.label}',
      ].join('\n');

  /// Turns Gemini's answer into product id -> category. Numbers not on the list are ignored,
  /// and spellings of one category that differ only in capitals are joined up.
  static Map<String, String> parse(String? text, List<Product> products, List<String> existing) {
    final raw = (text ?? '').replaceAll('```json', '').replaceAll('```', '').trim();
    if (raw.isEmpty) return {};
    final data = jsonDecode(raw);
    final list = data is Map ? data['assignments'] : null;
    if (list is! List) return {};
    final known = [...existing];
    final out = <String, String>{};
    for (final a in list) {
      if (a is! Map) continue;
      final n = a['number'];
      final name = matchCategory('${a['category'] ?? ''}', known);
      if (n is! num || n < 1 || n > products.length || n != n.roundToDouble() || name.isEmpty) continue;
      if (!known.contains(name)) known.add(name);
      out[products[n.toInt() - 1].id] = name;
    }
    return out;
  }

  /// A model that is busy or out of its daily allowance hands over to the next.
  static Future<Map<String, String>> suggest(List<Product> products, List<String> existing) async {
    Object? last;
    var answered = false;
    for (final name in _models) {
      try {
        final res = await FirebaseAI.googleAI()
            .generativeModel(
              model: name,
              generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema, temperature: 0),
            )
            .generateContent([Content.text(prompt(products, existing))])
            .timeout(const Duration(seconds: 30));
        answered = true;
        final found = parse(res.text, products, existing);
        if (found.isNotEmpty) return found;
      } catch (e) {
        last = e;
      }
    }
    if (answered) return {};
    throw last ?? StateError('No model answered');
  }
}
