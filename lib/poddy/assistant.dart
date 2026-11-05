import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../core/repo.dart';

/// Poddy's answer: a few plain words, and (for "how do I…" questions) the part of the
/// app to show, which the app turns into a short guided tour.
class PoddyAnswer {
  PoddyAnswer(this.answer, this.section);
  final String answer;
  final String section;
}

/// Ask Poddy: Gemini (Firebase AI Logic) answers questions about benj and the owner's
/// own shop. It only sees a short summary of the shop, never the full records.
class PoddyAssistant {
  /// Places Poddy can take the owner to. Keep in step with ShellState._guideSteps.
  static const sections = [
    'none', 'home', 'log_sold', 'log_count', 'log_bought', 'add_product', 'delete_product', 'duplicates',
    'buy', 'budget', 'stock', 'forecast', 'restock_day', 'calendar', 'shop_details', 'privacy', 'delete_account', 'sign_out',
  ];

  static final _schema = Schema.object(properties: {
    'answer': Schema.string(description: 'One or two short, friendly sentences in plain English. No markdown.'),
    'section': Schema.enumString(enumValues: sections, description: 'The part of the app that does what the owner asked, or none.'),
  });

  static const _guide = '''
benj helps a small shop owner in Ghana know what to restock, how much, and when. Tabs at the bottom: Home, Log, Buy, Stock. Settings is the gear icon at the top right.
- Home: what is running low with days left, the start of this week's buying list, "Log today's sales", days logged this week.
- Log: three modes at the top. Sold: tap + for each one sold today, then Save. Count: type how many are on the shelf now. Bought: record what was bought at the market and the price per unit. "Add a product" is at the bottom of Log.
- Adding a product: a full page with Type, Speak (say it, Poddy fills the form) or Photo (a label, shelf or stock-book page). Units: bag, pack, carton, crate, bottle, tin, piece, olonka.
- Deleting a product: Stock tab, tap the product, tap the bin icon at the top right, confirm Delete.
- Duplicates: Settings > Products > Remove duplicates merges the same product listed twice, keeping its logs.
- Buy: this week's buying list ("Buy 2 bags of Rice 4.5 kg"), adjusted for campus events. Type the cash you have and the most urgent items come first. "Record what I bought" opens Log in Bought mode. "Send to WhatsApp" shares the list.
- Stock: a chart of each product's stock over time, week or month, sorted by lowest stock, fastest moving or name. Tap a product to see "Was benj right?" (forecast vs actual), its warning level and recent logs.
- Warnings: benj warns before an item runs out. The owner can set a warning level per product (edit the product), or leave it blank and benj suggests one after 3 days of logs.
- Settings: shop details, usual restock day, products, campus calendar events (exams, breaks: busier or quieter), logging numbers, About, Privacy, Credits, Sign out, Delete account (the very last item).
- Forecasts need about 3 days of logs. Owners sign in with business name, phone or email and password. Forgot password: the sign-in page, using the account email. Help: benj.support@gmail.com.
''';

  static String _shopSummary(ShopRepo repo) {
    final shop = repo.shop;
    final lines = <String>[
      'Shop: ${shop?.name ?? ''}. Usual restock day: ${shop?.restockDay ?? 'not set'} (1 = Monday).',
      'Logged today: ${repo.loggedToday ? 'yes' : 'no'}. Days logged in the last 7: ${repo.lastSevenLogged.where((d) => d).length}.',
      'Products (${repo.products.length}):',
    ];
    for (final (p, f) in repo.rows.take(40)) {
      lines.add('- ${p.label}: ${f.stock.round()} ${p.plural(f.stock)} on the shelf'
          '${f.learning ? ', still learning' : ', sells about ${f.meanDaily.toStringAsFixed(1)} a day'}'
          '${f.daysLeft == null ? '' : ', about ${f.daysLeft!.floor()} days left'}'
          '${f.isLow ? ', RUNNING LOW' : ''}'
          '${f.suggestedQty > 0 ? ', buy ${f.suggestedQty} this week' : ''}.');
    }
    return lines.join('\n');
  }

  static Future<PoddyAnswer> ask(String question, ShopRepo repo) async {
    final prompt = 'You are Poddy, the friendly helper inside the benj app. Answer the owner briefly.\n'
        'If they ask how to do something in benj, explain it in one or two sentences and set section to where it is done.\n'
        'If they ask about their shop (what is low, what to buy), answer only from the shop summary; never invent numbers.\n'
        'If the question has nothing to do with their shop or benj, say kindly that you help with their shop and benj, and set section to none.\n\n'
        'HOW BENJ WORKS:\n$_guide\nTHIS SHOP RIGHT NOW:\n${_shopSummary(repo)}\n\nOWNER ASKS: "$question"';
    Object? last;
    for (final name in const ['gemini-3.5-flash-lite', 'gemini-3.8-flash']) {
      try {
        final res = await FirebaseAI.googleAI()
            .generativeModel(model: name, generationConfig: GenerationConfig(responseMimeType: 'application/json', responseSchema: _schema, temperature: 0.2))
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 25));
        final data = jsonDecode((res.text ?? '{}').replaceAll('```json', '').replaceAll('```', '').trim()) as Map<String, dynamic>;
        final section = sections.contains(data['section']) ? data['section'] as String : 'none';
        return PoddyAnswer('${data['answer'] ?? ''}'.trim(), section);
      } catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('Poddy could not answer');
  }
}
