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
  /// Both stable models from the Firebase AI Logic models page. The free tier gives each
  /// model its own small daily allowance (gemini-3.8-flash: 20 requests a day), so speech,
  /// which is easy, starts on the light model, and photos start on the stronger one.
  /// If one is busy or out of allowance, the other takes over.
  static const strong = 'gemini-3.8-flash', light = 'gemini-3.5-flash-lite';
  static const speechModels = [light, strong];
  static const photoModels = [strong, light];

  static final _schema = Schema.object(properties: {
    'products': Schema.array(
      items: Schema.object(
        properties: {
          'name': Schema.string(description: 'Product name without the size, e.g. "Rice", "Milo", "Indomie noodles".'),
          'size': Schema.string(description: 'Size or weight if stated, written with digits and a space, e.g. "1 kg" (for "one kilo" or "1kg"), "4.5 kg", "500 ml". Empty if none.'),
          'unit': Schema.enumString(enumValues: kUnits, description: 'How it is counted.'),
          // Required but nullable: the model must answer each one (a number, or null when it
          // really isn't there) instead of quietly leaving counts and prices out.
          'onHand': Schema.number(nullable: true, description: 'How many are in stock / on the shelf now. In "30 bags" it is 30. null if not stated.'),
          'costPrice': Schema.number(nullable: true, description: 'What the owner pays for one unit, in Ghana cedis. In "GHS 18" or "I buy it eighteen cedis" it is 18. null if not stated.'),
          'sellPrice': Schema.number(nullable: true, description: 'What the owner sells one unit for, in Ghana cedis, only when selling is mentioned. null otherwise.'),
        },
        optionalProperties: ['size', 'unit'],
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

  /// Each model gets two tries, a second apart, before moving to the next. When the daily
  /// allowance is used up, retrying cannot help, so it moves on straight away.
  static Future<GenerateContentResponse> _generate(List<String> models, List<Content> content, Duration timeout) async {
    Object? last;
    for (final name in models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _model(name).generateContent(content).timeout(timeout);
        } catch (e) {
          last = e;
          if (e is QuotaExceeded || '$e'.contains('quota')) break;
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
    final res = await _generate(speechModels, [Content.text('$_rules\n\nThe owner said: "$transcript"')], const Duration(seconds: 30));
    return _parse(res.text);
  }

  /// A product label, a shelf, or a stock-book page -> one or more drafts.
  static Future<List<ProductDraft>> fromPhoto(Uint8List bytes, String mimeType) async {
    final res = await _generate(photoModels, [
      Content.multi([
        TextPart('$_rules\n\nThis photo is a product, its label or price tag, a shelf, or a handwritten stock book page. '
            'List each distinct product you can read. For a stock book, use the latest counts and prices written.'),
        InlineDataPart(mimeType, bytes),
      ]),
    ], const Duration(seconds: 45));
    return _parse(res.text);
  }
}
