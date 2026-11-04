import 'forecast.dart';
import 'models.dart';

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

num tidy(double v) => v == v.roundToDouble() ? v.round() : double.parse(v.toStringAsFixed(1));

String dayName(DateTime d) => _days[d.weekday - 1];

/// "Buy 2 bags of Rice 4.5 kg": the plain-language line from F5.
String buyLine(Product p, int qty) => 'Buy $qty ${p.plural(qty)} of ${p.label}';

String daysLeftText(Forecast f) {
  final d = f.daysLeft;
  if (f.stock <= 0) return 'Finished';
  if (d == null) return 'Not selling yet';
  if (d < 1) return 'Runs out today';
  if (d < 2) return 'About 1 day left';
  return 'About ${d.floor()} days left';
}

/// The date to act by: the restock day, or sooner if the item runs out first.
DateTime buyBy(Forecast f, DateTime today) {
  final restock = today.add(Duration(days: f.leadDays));
  final d = f.daysLeft;
  if (d == null) return restock;
  final out = today.add(Duration(days: d.floor()));
  return out.isBefore(restock) ? out : restock;
}

/// The sentence on the home screen, e.g. "Buy 3 cartons of noodles and 2 bags of rice by Thursday".
String homeAnswer(List<(Product, Forecast)> rows, DateTime today) {
  final buying = rows.where((r) => r.$2.suggestedQty > 0 && !r.$2.learning).toList()..sort((a, b) => (a.$2.daysLeft ?? 999).compareTo(b.$2.daysLeft ?? 999));
  if (buying.isEmpty) return '';
  final top = buying.take(2).map((r) => '${r.$2.suggestedQty} ${r.$1.plural(r.$2.suggestedQty)} of ${r.$1.label}').toList();
  final by = buyBy(buying.first.$2, today);
  final more = buying.length - top.length;
  final when = by == today ? 'today' : 'by ${dayName(by)}';
  return 'Buy ${top.join(' and ')}${more > 0 ? ' (+$more more)' : ''} $when';
}
