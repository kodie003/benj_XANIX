import 'dart:convert';
import 'dart:io';

import 'package:benj/core/forecast.dart';
import 'package:benj/core/models.dart';
import 'package:benj/core/voice_parser.dart';
import 'package:benj/core/auth_service.dart';
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

  group('voice', () {
    final products = [p('r1', 'Rice', size: '1 kg'), p('r45', 'Rice', size: '4.5 kg'), p('n', 'Noodles', unit: 'carton'), p('m', 'Milo', unit: 'tin')];

    test('the PRD example: sold five small rice', () {
      final e = parseSpeech('sold five small rice', products).single;
      expect(e.product.id, 'r1');
      expect(e.quantity, 5);
      expect(e.type, 'sale');
    });
    test('big means the largest variant', () {
      expect(parseSpeech('sold 2 big rice', products).single.product.id, 'r45');
    });
    test('a spoken size is not a quantity', () {
      final e = parseSpeech('sold three rice 4.5 kg', products).single;
      expect(e.product.id, 'r45');
      expect(e.quantity, 3);
    });
    test('several items in one breath', () {
      final e = parseSpeech('sold five small rice and two noodles', products);
      expect(e.map((x) => x.product.id), ['r1', 'n']);
      expect(e.map((x) => x.quantity), [5, 2]);
    });
    test('bought means restock, left means count', () {
      expect(parseSpeech('bought ten cartons of noodles', products).single.type, 'restock');
      expect(parseSpeech('twelve milo left', products).single.type, 'count');
    });
    test('compound numbers', () {
      expect(parseSpeech('sold twenty five noodles', products).single.quantity, 25);
    });
    test('unknown words save nothing', () {
      expect(parseSpeech('good morning how are you', products), isEmpty);
      expect(parseSpeech('sold five bananas', products), isEmpty);
    });
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

  group('phone numbers', () {
    test('local Ghanaian numbers become international', () {
      expect(AuthService.normalisePhone('024 123 4567'), '+233241234567');
      expect(AuthService.normalisePhone('241234567'), '+233241234567');
      expect(AuthService.normalisePhone('+233 24 123 4567'), '+233241234567');
      expect(AuthService.normalisePhone('233241234567'), '+233241234567');
      expect(AuthService.looksValidPhone('+233241234567'), true);
      expect(AuthService.looksValidPhone('+2332'), false);
    });
  });
}
