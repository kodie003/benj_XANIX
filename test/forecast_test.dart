import 'dart:convert';
import 'dart:io';

import 'package:benj/core/forecast.dart';
import 'package:benj/core/models.dart';
import 'package:benj/auth_service.dart';
import 'package:benj/core/countries.dart';
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
}
