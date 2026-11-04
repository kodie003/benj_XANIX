import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/repo.dart';
import 'product.dart';
import 'ui.dart';

/// F8 stock dashboard: a line per product, weekly or monthly, sortable, today marked,
/// and variants of one product (rice 1 kg, rice 4.5 kg) in shades of one colour.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.repo});
  final ShopRepo repo;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

enum _Sort { name, lowest, fastest }

class _StockScreenState extends State<StockScreen> {
  int _days = 7;
  _Sort _sort = _Sort.lowest;
  final _hidden = <String>{};

  static const _hues = [140.0, 210.0, 25.0, 280.0, 350.0, 50.0, 180.0, 320.0];

  /// One hue per product group, darker or lighter per variant.
  Map<String, Color> _colors(List<Product> products) {
    final groups = <String, List<Product>>{};
    for (final p in products) {
      (groups[p.group] ??= []).add(p);
    }
    final out = <String, Color>{};
    var g = 0;
    for (final list in groups.values) {
      final hue = _hues[g++ % _hues.length];
      for (var i = 0; i < list.length; i++) {
        final light = list.length == 1 ? 0.42 : 0.30 + 0.30 * i / (list.length - 1);
        out[list[i].id] = HSLColor.fromAHSL(1, hue, 0.65, light).toColor();
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final text = Theme.of(context).textTheme;
    if (repo.products.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        Empty(icon: Icons.show_chart, text: 'Add products and log stock. Their levels over time show up here.'),
      ]);
    }
    final rows = [...repo.rows];
    switch (_sort) {
      case _Sort.name:
        rows.sort((a, b) => a.$1.label.toLowerCase().compareTo(b.$1.label.toLowerCase()));
      case _Sort.lowest:
        rows.sort((a, b) => (a.$2.daysLeft ?? (a.$2.stock <= 0 ? -1 : 999)).compareTo(b.$2.daysLeft ?? (b.$2.stock <= 0 ? -1 : 999)));
      case _Sort.fastest:
        rows.sort((a, b) => b.$2.meanDaily.compareTo(a.$2.meanDaily));
    }
    final colors = _colors(repo.products);
    final series = {for (final (p, _) in rows) p.id: stockHistory(repo.logsFor(p.id), repo.today, _days)};
    var maxY = 1.0;
    for (final s in series.values) {
      for (final v in s) {
        if (v != null && v > maxY) maxY = v;
      }
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 220), children: [
      Row(children: [
        Expanded(child: Text('Stock over time', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 7, label: Text('Week')), ButtonSegment(value: 30, label: Text('Month'))],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
      ]),
      const SizedBox(height: 16),
      SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: (maxY * 1.15).ceilToDouble(),
            minX: 0,
            maxX: (_days - 1).toDouble(),
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: true),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _days == 7 ? 1 : 7,
                  getTitlesWidget: (v, meta) {
                    final d = repo.today.subtract(Duration(days: _days - 1 - v.round()));
                    final label = _days == 7 ? weekdays[d.weekday - 1].substring(0, 3) : '${d.day}/${d.month}';
                    return SideTitleWidget(meta: meta, child: Text(label, style: text.labelSmall));
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(verticalLines: [
              VerticalLine(
                x: (_days - 1).toDouble(),
                color: Theme.of(context).colorScheme.outline,
                dashArray: [4, 4],
                label: VerticalLineLabel(show: true, alignment: Alignment.topLeft, labelResolver: (_) => 'Today', style: text.labelSmall),
              ),
            ]),
            lineBarsData: [
              for (final (p, _) in rows)
                if (!_hidden.contains(p.id))
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < _days; i++) series[p.id]![i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), series[p.id]![i]!),
                    ],
                    color: colors[p.id],
                    barWidth: 3,
                    dotData: FlDotData(show: _days == 7),
                  ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (p, _) in rows)
          FilterChip(
            avatar: CircleAvatar(backgroundColor: colors[p.id], radius: 6),
            label: Text(p.label),
            selected: !_hidden.contains(p.id),
            onSelected: (on) => setState(() => on ? _hidden.remove(p.id) : _hidden.add(p.id)),
          ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text('Sort by', style: text.labelLarge),
        const SizedBox(width: 10),
        DropdownButton<_Sort>(
          value: _sort,
          onChanged: (v) => setState(() => _sort = v!),
          items: const [
            DropdownMenuItem(value: _Sort.lowest, child: Text('Lowest stock')),
            DropdownMenuItem(value: _Sort.fastest, child: Text('Fastest moving')),
            DropdownMenuItem(value: _Sort.name, child: Text('Name')),
          ],
        ),
      ]),
      for (final (p, f) in rows)
        Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: colors[p.id], radius: 8),
            title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              '${units(p, f.stock)} on the shelf',
              if (f.meanDaily > 0) 'sells about ${qty(double.parse(f.meanDaily.toStringAsFixed(1)))} a day',
              ?daysLeftText(f),
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openProduct(context, repo, p),
          ),
        ),
    ]);
  }
}
