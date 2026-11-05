import 'dart:convert';
import 'dart:io';

import 'package:benj/core/categories.dart';
import 'package:benj/core/forecast.dart';
import 'package:benj/core/models.dart';
import 'package:benj/auth_service.dart';
import 'package:benj/core/countries.dart';
import 'package:benj/core/reader.dart';
import 'package:benj/screens/stock.dart';
import 'package:flutter/painting.dart' show HSLColor;
import 'package:flutter_test/flutter_test.dart';

Product p(String id, String name, {String size = '', String unit = 'bag', double? warn}) => Product(id: id, name: name, unit: unit, size: size, warningLevel: warn);

void main() {
  group('matches the Python service', () {
    final vectors = jsonDecode(File('tests/forecast_vectors.json').readAsStringSync()) as List;
    for (final v in vectors) {
      test(v['name'], () {
        final today = DateTime.parse(v['today']);
        final logs = [
          for (final l in v['logs']) StockLog(product: v['product']['id'], at: DateTime.parse(l['at']), type: l['type'], quantity: (l['quantity'] as num).toDouble()),
        ];
        final events = [
          for (final e in v['events']) ShopEvent(name: 'e', start: DateTime.parse(e['start']), end: DateTime.parse(e['end']), factor: (e['factor'] as num).toDouble()),
        ];
        final f = forecastProduct(p(v['product']['id'], 'x', warn: (v['product']['warningLevel'] as num?)?.toDouble()), logs, events, today, v['restockDay']);
        final e = v['expect'];
        expect(f.stock, closeTo(e['stock'], .01));
        expect(f.meanDaily, closeTo(e['meanDaily'], .01));
        expect(f.sdDaily, closeTo(e['sdDaily'], .01));
        expect(f.daysOfData, e['daysOfData']);
        expect(f.factor, closeTo(e['factor'], .01));
        expect(f.leadDays, e['leadDays']);
        expect(f.suggestedWarning, e['suggestedWarning']);
        expect(f.warningLevel, closeTo(e['warningLevel'], .01));
        expect(f.isLow, e['isLow']);
        if (e['daysLeft'] == null) {
          expect(f.daysLeft, isNull);
        } else {
          expect(f.daysLeft, closeTo(e['daysLeft'], .01));
        }
        expect(f.weekDemand, closeTo(e['weekDemand'], .01));
        expect(f.suggestedQty, e['suggestedQty']);
      });
    }
  });

  group('budget', () {
    Forecast f(String id, double days, int qty) => Forecast(product: id, stock: 1, meanDaily: 1, sdDaily: 0, daysOfData: 5, factor: 1, leadDays: 5, suggestedWarning: 1, warningLevel: 1, isLow: false, daysLeft: days, weekDemand: 7, suggestedQty: qty);
    test('most at-risk first, and cash runs out where it should', () {
      final plan = budgetPlan([
        (Product(id: 'slow', name: 'Slow', unit: 'bag', costPrice: 10), f('slow', 9, 5)),
        (Product(id: 'urgent', name: 'Urgent', unit: 'bag', costPrice: 10), f('urgent', 1, 5)),
      ], 70);
      expect(plan[0].product.id, 'urgent');
      expect(plan[0].buy, 5);
      expect(plan[1].buy, 2);
    });
  });

  group('photo reading', () {
    test('the same product written twice becomes one, with counts added', () {
      final merged = ProductReader.mergeSame([
        ProductDraft(name: 'Rice', size: '1 kg', unit: 'bag', onHand: 20, costPrice: 18),
        ProductDraft(name: 'Milo', unit: 'tin', onHand: 12),
        ProductDraft(name: 'rice', size: '1kg', unit: 'bag', onHand: 10),
      ]);
      expect(merged.length, 2);
      final rice = merged.firstWhere((d) => d.name == 'Rice');
      expect(rice.onHand, 30);
      expect(rice.seen, 2);
      expect(rice.costPrice, 18);
    });
    test('"Rice 1 kg" and "rice 1kg" count as the same product', () {
      expect(Product.keyOf('Rice', '1 kg'), Product.keyOf('rice', '1kg'));
      expect(Product.keyOf('Rice', '1 kg'), isNot(Product.keyOf('Rice', '4.5 kg')));
    });
    test('olonka is a unit', () {
      expect(kUnits, contains('olonka'));
      expect(Product(id: 'g', name: 'Gari', unit: 'olonka').plural(3), 'olonkas');
    });
  });

  group('phone numbers', () {
    test('local Ghanaian numbers become international', () {
      expect(AuthService.normalisePhone('024 123 4567'), '+233241234567');
      expect(AuthService.normalisePhone('241234567'), '+233241234567');
      expect(AuthService.normalisePhone('+233 24 123 4567'), '+233241234567');
      expect(AuthService.normalisePhone('233241234567'), '+233241234567');
      expect(AuthService.looksValidPhone('+233241234567'), true);
      expect(AuthService.looksValidPhone('+2332'), false);
    });
    test('Ghana: exactly 10 digits starting with 0, then +233', () {
      expect(ghana.toE164('0241234567'), '+233241234567');
      expect(ghana.toE164('024 123 4567'), '+233241234567');
      expect(ghana.toE164('241234567'), isNull); // 9 digits
      expect(ghana.toE164('02412345678'), isNull); // 11 digits
      expect(ghana.toE164('1241234567'), isNull); // no leading 0
    });
    test('other countries use their own length and code', () {
      final ng = countries.firstWhere((c) => c.name == 'Nigeria');
      final us = countries.firstWhere((c) => c.name == 'United States');
      expect(ng.toE164('08012345678'), '+2348012345678');
      expect(us.toE164('2015550123'), '+12015550123');
      expect(us.toE164('201555012'), isNull);
    });
    test('a benj account login is the number at a reserved address', () {
      expect(AuthService.phoneLogin('+233241234567'), '233241234567@phone.benj.invalid');
    });
  });

  group('categories', () {
    final milk = p('a', 'Peak Milk', unit: 'tin');
    final soap = p('b', 'Key Soap', unit: 'piece');

    test('names are tidied and join the spelling the owner already uses', () {
      expect(cleanCategory('  toiletries   and  soap '), 'Toiletries and soap');
      expect(matchCategory('PROVISIONS', ['Provisions']), 'Provisions');
      expect(matchCategory('drinks', ['Provisions']), 'Drinks');
      expect(cleanCategory('x' * 80).length, kCategoryMax);
    });

    test('groups run A to Z with unsorted products last', () {
      final all = [
        Product(id: '1', name: 'Soap', unit: 'piece', category: 'Toiletries'),
        Product(id: '2', name: 'Pen', unit: 'piece'),
        Product(id: '3', name: 'Rice', unit: 'bag', category: 'Provisions'),
      ];
      expect(groupByCategory(all).map((g) => g.$1).toList(), ['Provisions', 'Toiletries', kNotSorted]);
    });

    test('a suggestion maps numbers to products and ignores nonsense', () {
      const answer = '{"assignments":[{"number":1,"category":"provisions"},{"number":2,"category":"Toiletries"},'
          '{"number":9,"category":"Drinks"},{"number":1.5,"category":"Drinks"},{"number":2,"category":" "}]}';
      expect(CategorySuggester.parse(answer, [milk, soap], ['Provisions']), {'a': 'Provisions', 'b': 'Toiletries'});
      expect(CategorySuggester.parse('', [milk], []), isEmpty);
      expect(CategorySuggester.parse('{"assignments":"no"}', [milk], []), isEmpty);
    });

    test('the prompt numbers every product and reuses existing categories', () {
      final text = CategorySuggester.prompt([milk, soap], ['Provisions']);
      expect(text, contains('1. Peak Milk'));
      expect(text, contains('2. Key Soap'));
      expect(text, contains('already uses these categories, so reuse them whenever they fit: Provisions.'));
    });

    test('a product keeps its category through saving', () {
      expect(Product(id: '1', name: 'Soap', unit: 'piece', category: 'Toiletries').toMap()['category'], 'Toiletries');
    });
  });

  group('stock chart', () {
    final today = DateTime(2026, 11, 5);
    (Product, Forecast) row(String id, double count) {
      final product = p(id, id);
      return (product, forecastProduct(product, [StockLog(product: id, at: today, type: 'count', quantity: count)], [], today, null));
    }

    test('lowest stock comes first even with no sales yet', () {
      final rows = [row('Coke', 4), row('Rice', 1), row('Milo', 2)]..sort(lowestFirst);
      expect(rows.map((r) => r.$1.id).toList(), ['Rice', 'Milo', 'Coke']);
    });

    test('every product gets its own colour; variants share a hue', () {
      final many = [for (var i = 0; i < 30; i++) p('$i', 'Product $i')];
      expect(productColors(many).values.toSet().length, 30);
      final rice = productColors([p('a', 'Rice', size: '1 kg'), p('b', 'Rice', size: '5 kg')]);
      expect(rice['a'], isNot(rice['b']));
      expect(HSLColor.fromColor(rice['a']!).hue, closeTo(HSLColor.fromColor(rice['b']!).hue, 1));
    });

    test('a line needs a second day: one count shows only on its day, then carries forward', () {
      final logs = [StockLog(product: 'a', at: today.subtract(const Duration(days: 2)), type: 'count', quantity: 10), StockLog(product: 'a', at: today, type: 'sale', quantity: 3)];
      expect(stockHistory(logs, today, 4), [null, 10, 10, 7]);
      expect(stockHistory([logs.last], today, 2).where((v) => v != null).length, 1);
    });
  });
}
