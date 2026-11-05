import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/repo.dart';
import 'categories.dart';
import 'product.dart';
import 'ui.dart';

/// Every product gets its own colour; variants of one product (rice 1 kg, rice 4.5 kg)
/// share a hue in different shades. The golden angle keeps neighbouring hues far apart,
/// however many products there are.
Map<String, Color> productColors(List<Product> products) {
  final groups = <String, List<Product>>{};
  for (final p in products) {
    (groups[p.group] ??= []).add(p);
  }
  final out = <String, Color>{};
  var g = 0;
  for (final list in groups.values) {
    final hue = (140 + g * 137.508) % 360;
    final base = g.isEven ? 0.40 : 0.50;
    for (var i = 0; i < list.length; i++) {
      final light = list.length == 1 ? base : 0.30 + 0.30 * i / (list.length - 1);
      out[list[i].id] = HSLColor.fromAHSL(1, hue, 0.70, light).toColor();
    }
    g++;
  }
  return out;
}

/// F8 stock dashboard: a line per product, weekly or monthly, by category, sortable,
/// today marked, one colour per product.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.repo});
  final ShopRepo repo;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

enum _Sort { name, lowest, fastest }

class _StockScreenState extends State<StockScreen> {
  static const _startLines = 5;
  static const _all = '';

  int _days = 7;
  _Sort _sort = _Sort.lowest;

  /// The category in focus; empty shows them all.
  String _category = _all;

  /// Products the owner chose to draw; null means the five lowest.
  Set<String>? _picked;

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (repo.products.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        Empty(icon: Icons.show_chart, text: 'Add products and log stock. Their levels over time show up here.'),
      ]);
    }
    final groups = groupByCategory(repo.products);
    final hasCategories = repo.categories.isNotEmpty;
    if (_category != _all && !groups.any((g) => g.$1 == _category)) _category = _all;
    bool inView(Product p) => _category == _all || (p.category.isEmpty ? kNotSorted : p.category) == _category;
    final offer = repo.unsorted.isNotEmpty && repo.products.length > 1 && !repo.hideSortOffer;

    final lowest = [for (final r in repo.rows) if (inView(r.$1)) r]..sort(lowestFirst);
    final rows = [...lowest];
    switch (_sort) {
      case _Sort.name:
        rows.sort((a, b) => a.$1.label.toLowerCase().compareTo(b.$1.label.toLowerCase()));
      case _Sort.lowest:
        break;
      case _Sort.fastest:
        rows.sort((a, b) => b.$2.meanDaily.compareTo(a.$2.meanDaily));
    }

    final colors = productColors(repo.products);
    final picked = _picked ?? {for (final r in lowest.take(_startLines)) r.$1.id};
    final drawn = [for (final (p, _) in rows) if (picked.contains(p.id)) p];
    final series = {for (final p in drawn) p.id: stockHistory(repo.logsFor(p.id), repo.today, _days)};
    var maxY = 1.0;
    var hasLine = false;
    for (final s in series.values) {
      if (s.where((v) => v != null).length > 1) hasLine = true;
      for (final v in s) {
        if (v != null && v > maxY) maxY = v;
      }
    }
    // Whole numbers only: nobody has half a bag on the axis.
    final top = (maxY * 1.15).ceilToDouble();
    final step = math.max(1, (top / 4).ceil()).toDouble();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 220), children: [
      Row(children: [
        Expanded(child: Text('Stock over time', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 7, label: Text('Week')), ButtonSegment(value: 30, label: Text('Month'))],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
      ]),
      if (offer)
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text('Poddy can sort ${repo.unsorted.length} ${repo.unsorted.length == 1 ? 'product' : 'products'} into categories.'),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => openCategories(context, repo, suggest: true), child: const Text('Sort them')),
            ),
            trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Not now', onPressed: () => setState(() => repo.hideSortOffer = true)),
          ),
        ),
      if (hasCategories)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _category,
                onChanged: (v) => setState(() {
                  _category = v!;
                  _picked = null;
                }),
                items: [
                  DropdownMenuItem(value: _all, child: Text('All categories (${repo.products.length})')),
                  for (final (name, list) in groups) DropdownMenuItem(value: name, child: Text('$name (${list.length})')),
                ],
              ),
            ),
            TextButton.icon(onPressed: () => openCategories(context, repo), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit categories')),
          ]),
        ),
      const SizedBox(height: 16),
      SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: top,
            minX: 0,
            maxX: (_days - 1).toDouble(),
            gridData: FlGridData(drawVerticalLine: false, horizontalInterval: step),
            borderData: FlBorderData(show: false),
            // Products on the same count sit on one dot, so a tap lists them all.
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${drawn[s.barIndex].label}: ${qty(s.y)}',
                      TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                ],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: step)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _days == 7 ? 1 : 7,
                  getTitlesWidget: (v, meta) {
                    final d = repo.today.subtract(Duration(days: _days - 1 - v.round()));
                    final label = _days == 7 ? weekdays[d.weekday - 1].substring(0, 3) : '${d.day}/${d.month}';
                    return SideTitleWidget(meta: meta, fitInside: SideTitleFitInsideData.fromTitleMeta(meta), child: Text(label, style: text.labelSmall));
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(verticalLines: [
              VerticalLine(
                x: (_days - 1).toDouble(),
                color: scheme.outline,
                dashArray: [4, 4],
                label: VerticalLineLabel(show: true, alignment: Alignment.topLeft, labelResolver: (_) => 'Today', style: text.labelSmall),
              ),
            ]),
            lineBarsData: [
              for (final p in drawn)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < _days; i++) series[p.id]![i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), series[p.id]![i]!),
                  ],
                  color: colors[p.id],
                  barWidth: 3,
                  // A month of dots is clutter, but a single day has nothing else to show.
                  dotData: FlDotData(show: _days == 7 || series[p.id]!.where((v) => v != null).length < 2),
                ),
            ],
          ),
        ),
      ),
      if (!hasLine)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Your lines start after your second day of logging.', textAlign: TextAlign.center, style: text.bodySmall),
        ),
      const SizedBox(height: 8),
      if (_picked == null && rows.length > _startLines)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Showing the $_startLines lowest. Tap a name to add or remove its line.', style: text.bodySmall),
        ),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (p, _) in rows)
          FilterChip(
            showCheckmark: false,
            avatar: CircleAvatar(backgroundColor: colors[p.id], radius: 6),
            label: Text(p.label),
            selected: picked.contains(p.id),
            onSelected: (on) => setState(() {
              final next = {...picked};
              on ? next.add(p.id) : next.remove(p.id);
              _picked = next;
            }),
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
