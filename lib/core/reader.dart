import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import 'models.dart';

/// A product read from speech or a photo, before the owner checks and saves it.
class ProductDraft {
  ProductDraft({this.name = '', this.size = '', this.unit = '', this.onHand, this.costPrice, this.sellPrice});
  String name, size, unit;
  double? onHand, costPrice, sellPrice;

  String get label => size.isEmpty ? name : '$name $size';

  factory ProductDraft.fromJson(Map<String, dynamic> j) {
    double? n(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    final unit = '${j['unit'] ?? ''}'.toLowerCase().trim();
    // "rice" said aloud becomes "Rice" in the list.
    final rawName = '${j['name'] ?? ''}'.trim();
    final name = rawName.isEmpty ? '' : rawName[0].toUpperCase() + rawName.substring(1);
    return ProductDraft(
      name: name,
      size: '${j['size'] ?? ''}'.trim(),
      unit: kUnits.contains(unit) ? unit : '',
      onHand: n(j['onHand']),
      costPrice: n(j['costPrice']),
      sellPrice: n(j['sellPrice']),
    );
  }
}

/// Reads products from what the owner said or photographed, using Gemini through
/// Firebase AI Logic. It never saves anything: the owner checks every field first.
class ProductReader {
  /// Tried in order: when Google says a model is busy, benj waits a moment, retries,
  /// then falls back to the lighter model (both stable, Firebase AI Logic models page).
  static const models = ['gemini-3.8-flash', 'gemini-3.5-flash-lite'];

  static final _schema = Schema.object(properties: {
    'products': Schema.array(
      items: Schema.object(
        properties: {
          'name': Schema.string(description: 'Product name without the size, e.g. "Rice", "Milo", "Indomie noodles".'),
          'size': Schema.string(description: 'Size or weight if stated, e.g. "1 kg", "4.5 kg", "500 ml". Empty if none.'),
          'unit': Schema.enumString(enumValues: kUnits, description: 'How it is counted.'),
          'onHand': Schema.number(description: 'How many are in stock / on the shelf now, if stated.'),
          'costPrice': Schema.number(description: 'What the owner pays for one unit, in Ghana cedis, if stated.'),
          'sellPrice': Schema.number(description: 'What the owner sells one unit for, in Ghana cedis, if stated.'),
        },
        optionalProperties: ['size', 'unit', 'onHand', 'costPrice', 'sellPrice'],
      ),
    ),
  });

  static const _rules =
      'You help a small shop owner in Ghana add the products they sell to a stock app. '
      'Prices are in Ghana cedis (GHS, "cedis", "ghana"). Numbers may be spoken as words or in local English. '
      'Pick unit from: ${'bag, pack, carton, crate, bottle, tin, piece'}. '
      'Only include what is actually said or clearly written. Never invent prices or counts. '
      'In a stock book line like "Rice 1kg - 30 bags - GHS 18", 30 is onHand and 18 is costPrice. '
      'A single price with no other wording is what the owner pays (costPrice); use sellPrice only when it says sell, sale or selling. '
      'If nothing usable is there, return an empty products list.';

  static GenerativeModel _model(String name) => FirebaseAI.googleAI().generativeModel(
        model: name,
        generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema, temperature: 0),
      );

  /// Each model gets two tries, a second apart, before moving to the next.
  static Future<GenerateContentResponse> _generate(List<Content> content, Duration timeout) async {
    Object? last;
    for (final name in models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _model(name).generateContent(content).timeout(timeout);
        } catch (e) {
          last = e;
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        }
      }
    }
    throw last ?? StateError('No model answered');
  }

  static List<ProductDraft> _parse(String? text) {
    final raw = (text ?? '').replaceAll('```json', '').replaceAll('```', '').trim();
    if (raw.isEmpty) return [];
    final data = jsonDecode(raw);
    final list = data is Map ? (data['products'] as List? ?? []) : (data is List ? data : []);
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) ProductDraft.fromJson(e),
    ].where((d) => d.name.isNotEmpty).toList();
  }

  /// "Rice, one kilo, bag, thirty on the shelf, I pay eighteen cedis" -> one draft.
  static Future<List<ProductDraft>> fromSpeech(String transcript) async {
    final res = await _generate([Content.text('$_rules\n\nThe owner said: "$transcript"')], const Duration(seconds: 30));
    return _parse(res.text);
  }

  /// A product label, a shelf, or a stock-book page -> one or more drafts.
  static Future<List<ProductDraft>> fromPhoto(Uint8List bytes, String mimeType) async {
    final res = await _generate([
      Content.multi([
        TextPart('$_rules\n\nThis photo is a product, its label or price tag, a shelf, or a handwritten stock book page. '
            'List each distinct product you can read. For a stock book, use the latest counts and prices written.'),
        InlineDataPart(mimeType, bytes),
      ]),
    ], const Duration(seconds: 45));
    return _parse(res.text);
  }
}
