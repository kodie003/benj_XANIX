import 'dart:math' as math;

import 'models.dart';

/// Mirror of api/forecast.py, so warnings and buying lists keep working with no
/// network. tests/forecast_vectors.json checks both return the same numbers.
class Forecast {
  Forecast({
    required this.product,
    required this.stock,
    required this.meanDaily,
    required this.sdDaily,
    required this.daysOfData,
    required this.factor,
    required this.leadDays,
    required this.suggestedWarning,
    required this.warningLevel,
    required this.isLow,
    required this.daysLeft,
    required this.weekDemand,
    required this.suggestedQty,
  });

  final String product;
  final double stock, meanDaily, sdDaily, factor, warningLevel, weekDemand;
  final int daysOfData, leadDays, suggestedWarning, suggestedQty;
  final double? daysLeft;
  final bool isLow;
  bool get learning => daysOfData < 3;
}

const double kZ = 1.65; // about 95% cover
const int kWindowDays = 14;

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int nextRestock(DateTime today, int? restockDay) {
  if (restockDay == null || restockDay == 0) return 7;
  return ((restockDay - today.weekday - 1) % 7) + 1;
}

double factorOn(DateTime day, List<ShopEvent> events) {
  var f = 1.0;
  for (final e in events) {
    if (!day.isBefore(dayOnly(e.start)) && !day.isAfter(dayOnly(e.end))) f *= e.factor;
  }
  return f;
}

double averageFactor(DateTime today, int days, List<ShopEvent> events) {
  final n = math.max(1, days);
  var s = 0.0;
  for (var i = 1; i <= n; i++) {
    s += factorOn(today.add(Duration(days: i)), events);
  }
  return s / n;
}

class Replay {
  double stock = 0;
  final Map<DateTime, double> demand = {};
  final Set<DateTime> soldOut = {};
  DateTime? first;
}

Replay replay(List<StockLog> logs, DateTime today) {
  final r = Replay();
  final sorted = [...logs]..sort((a, b) => a.at.compareTo(b.at));
  DateTime? lastDay;
  // Days with no logs while the shelf is empty are sold-out days too.
  void carrySoldOut(DateTime until) {
    if (lastDay == null || r.stock > 0) return;
    var d = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    while (d.isBefore(until)) {
      r.soldOut.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
  }

  for (final log in sorted) {
    final day = dayOnly(log.at);
    if (day.isAfter(today)) continue;
    r.first ??= day;
    carrySoldOut(day);
    lastDay = day;
    switch (log.type) {
      case 'restock':
        r.stock += log.quantity;
      case 'sale':
        r.stock = math.max(0, r.stock - log.quantity);
        r.demand[day] = (r.demand[day] ?? 0) + log.quantity;
      case 'count':
        // A count below what we expected means units left that nobody logged.
        if (log.quantity < r.stock) r.demand[day] = (r.demand[day] ?? 0) + (r.stock - log.quantity);
        r.stock = log.quantity;
    }
    if (r.stock <= 0) {
      r.soldOut.add(day);
    } else {
      r.soldOut.remove(day);
    }
  }
  carrySoldOut(DateTime(today.year, today.month, today.day + 1));
  return r;
}

({double mean, double sd, int n}) demandStats(Replay r, DateTime today) {
  final first = r.first;
  if (first == null) return (mean: 0, sd: 0, n: 0);
  final windowStart = today.subtract(const Duration(days: kWindowDays));
  var d = first.isAfter(windowStart) ? first : windowStart;
  final days = <double>[];
  while (d.isBefore(today)) {
    // Sold-out days are skipped: zero sales there means no stock, not no demand.
    if (!r.soldOut.contains(d) || (r.demand[d] ?? 0) > 0) days.add(r.demand[d] ?? 0);
    d = DateTime(d.year, d.month, d.day + 1);
  }
  if (days.isEmpty) days.add(r.demand[today] ?? 0);
  final n = days.length;
  final mean = days.reduce((a, b) => a + b) / n;
  final sd = n > 1 ? math.sqrt(days.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / (n - 1)) : 0.0;
  return (mean: mean, sd: sd, n: n);
}

Forecast forecastProduct(Product p, List<StockLog> logs, List<ShopEvent> events, DateTime today, int? restockDay) {
  final r = replay(logs, today);
  final s = demandStats(r, today);
  final lead = nextRestock(today, restockDay);
  final fLead = averageFactor(today, lead, events);
  final fWeek = averageFactor(today, 7, events);
  final suggested = s.n > 0 ? (s.mean * fLead * lead + kZ * s.sd * math.sqrt(lead)).ceil() : 0;
  final warning = p.warningLevel ?? suggested.toDouble();
  final weekDemand = s.mean * fWeek * 7;
  final qty = s.n > 0 ? math.max(0, (weekDemand + kZ * s.sd * math.sqrt(7) - r.stock).ceil()) : 0;
  final rate = s.mean * fWeek;
  return Forecast(
    product: p.id,
    stock: r.stock,
    meanDaily: s.mean,
    sdDaily: s.sd,
    daysOfData: s.n,
    factor: fWeek,
    leadDays: lead,
    suggestedWarning: suggested,
    warningLevel: warning,
    isLow: (s.n > 0 && r.stock <= warning) || (r.first != null && r.stock <= 0),
    daysLeft: rate > 0 ? r.stock / rate : null,
    weekDemand: weekDemand,
    suggestedQty: qty,
  );
}

/// One row of F7: what we would have predicted for a past week against what happened.
/// Replaying the log "as of" that Monday also gives the backtest in PRD Test 2.
class WeekCheck {
  WeekCheck(this.weekStart, this.predicted, this.actual);
  final DateTime weekStart;
  final double predicted, actual;
  double get error => actual == 0 ? (predicted == 0 ? 0 : 1) : (predicted - actual).abs() / actual;
}

List<WeekCheck> weekChecks(Product p, List<StockLog> logs, List<ShopEvent> events, DateTime today, {int weeks = 6}) {
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final out = <WeekCheck>[];
  for (var w = weeks; w >= 1; w--) {
    final start = DateTime(monday.year, monday.month, monday.day - 7 * w);
    final end = DateTime(start.year, start.month, start.day + 7);
    final before = logs.where((l) => l.at.isBefore(start)).toList();
    if (before.isEmpty) continue;
    final r = replay(before, start);
    final s = demandStats(r, start);
    if (s.n < 3) continue; // Too little history at that point to call it a forecast.
    final predicted = s.mean * averageFactor(start.subtract(const Duration(days: 1)), 7, events) * 7;
    final all = replay(logs.where((l) => l.at.isBefore(end)).toList(), today);
    var actual = 0.0;
    for (var d = 0; d < 7; d++) {
      actual += all.demand[DateTime(start.year, start.month, start.day + d)] ?? 0;
    }
    out.add(WeekCheck(start, predicted, actual));
  }
  return out;
}

/// F8: stock on hand at the end of each of the last [days] days.
List<double?> stockHistory(List<StockLog> logs, DateTime today, int days) {
  final sorted = [...logs]..sort((a, b) => a.at.compareTo(b.at));
  final out = <double?>[];
  for (var i = days - 1; i >= 0; i--) {
    final end = DateTime(today.year, today.month, today.day - i + 1);
    final before = sorted.where((l) => l.at.isBefore(end)).toList();
    out.add(before.isEmpty ? null : replay(before, today).stock);
  }
  return out;
}

/// F12: when cash is short, spend it on what is most at risk and moves fastest.
List<({Product product, Forecast f, int buy, double cost})> budgetPlan(List<(Product, Forecast)> rows, double? cash) {
  final wanted = rows.where((r) => r.$2.suggestedQty > 0).toList()
    ..sort((a, b) {
      final da = a.$2.daysLeft ?? 999, db = b.$2.daysLeft ?? 999;
      if ((da - db).abs() > 0.01) return da.compareTo(db);
      return b.$2.meanDaily.compareTo(a.$2.meanDaily);
    });
  var left = cash;
  final out = <({Product product, Forecast f, int buy, double cost})>[];
  for (final (p, f) in wanted) {
    var buy = f.suggestedQty;
    final unit = p.costPrice ?? 0;
    if (left != null && unit > 0) {
      buy = math.min(buy, (left / unit).floor());
      left -= buy * unit;
    }
    out.add((product: p, f: f, buy: buy, cost: buy * unit));
  }
  return out;
}
