import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import '../fx/fx_view.dart';
import 'product_screen.dart';

const kSeries = [B.gold, B.teal, Color(0xFF6FA8FF), B.coral, B.violet, Color(0xFFFF8FD0), Color(0xFFB6F36A), Color(0xFFFFD9A0)];

/// F8 as a chart, plus the Stock Constellation: the same numbers as a place you can
/// fly around, where height is days of stock left and the floor is running out.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.repo});
  final ShopRepo repo;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  bool _sky = false;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
          child: Row(children: [
            Expanded(child: Text('Stock', style: B.display(28))),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(B.body(13.5, w: FontWeight.w700)),
                backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? B.gold : B.surface),
                foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF241600) : B.text),
              ),
              segments: const [ButtonSegment(value: false, label: Text('Chart')), ButtonSegment(value: true, label: Text('Sky'))],
              selected: {_sky},
              onSelectionChanged: (s) => setState(() => _sky = s.first),
            ),
          ]),
        ),
        Expanded(child: _sky ? _Constellation(repo: widget.repo) : _ChartTab(repo: widget.repo)),
      ]);
}

// ======================= Chart (F8) =======================
class _ChartTab extends StatefulWidget {
  const _ChartTab({required this.repo});
  final ShopRepo repo;

  @override
  State<_ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<_ChartTab> {
  int _days = 7;
  String _sort = 'lowest';
  final _hidden = <String>{};

  ShopRepo get r => widget.repo;

  List<(Product, Forecast)> get _sorted {
    final rows = [...r.rows];
    switch (_sort) {
      case 'name':
        rows.sort((a, b) => a.$1.label.compareTo(b.$1.label));
      case 'fastest':
        rows.sort((a, b) => b.$2.meanDaily.compareTo(a.$2.meanDaily));
      default:
        rows.sort((a, b) => a.$2.stock.compareTo(b.$2.stock));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sorted;
    final colors = {for (final (i, p) in r.products.indexed) p.id: kSeries[i % kSeries.length]};
    final series = [
      for (final (p, _) in rows)
        if (!_hidden.contains(p.id)) (color: colors[p.id]!, points: stockHistory(r.logsFor(p.id), r.today, _days)),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 110), children: [
      Row(children: [
        for (final d in const [(7, 'Week'), (30, 'Month')])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(d.$2),
              selected: _days == d.$1,
              selectedColor: B.gold,
              labelStyle: B.body(13.5, w: FontWeight.w700, color: _days == d.$1 ? const Color(0xFF241600) : B.text),
              onSelected: (_) => setState(() => _days = d.$1),
            ),
          ),
        const Spacer(),
        DropdownButton<String>(
          value: _sort,
          underline: const SizedBox.shrink(),
          dropdownColor: B.raised,
          style: B.body(14, w: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'lowest', child: Text('Lowest stock')),
            DropdownMenuItem(value: 'fastest', child: Text('Fastest moving')),
            DropdownMenuItem(value: 'name', child: Text('Name')),
          ],
          onChanged: (v) => setState(() => _sort = v!),
        ),
      ]),
      const SizedBox(height: 8),
      Panel(
        padding: const EdgeInsets.fromLTRB(10, 16, 14, 8),
        child: SizedBox(
          height: 240,
          child: rows.isEmpty
              ? Center(child: Text('Your stock lines will appear here.', style: B.body(14, color: B.mute)))
              : CustomPaint(size: Size.infinite, painter: _StockChart(series, _days, r.today)),
        ),
      ),
      const SizedBox(height: 10),
      for (final (p, f) in rows)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openProduct(context, r, p.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Row(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _hidden.contains(p.id) ? _hidden.remove(p.id) : _hidden.add(p.id)),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(width: 18, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: _hidden.contains(p.id) ? Colors.transparent : colors[p.id], border: Border.all(color: colors[p.id]!, width: 2))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(p.label, style: B.body(15, w: FontWeight.w600))),
              Text('${tidy(f.stock)} ${p.plural(f.stock)}', style: B.body(14, color: B.mute)),
              const SizedBox(width: 10),
              Pill(f.learning ? 'learning' : daysLeftText(f), color: f.learning ? B.mute : B.urgency(f.daysLeft, f.isLow)),
            ]),
          ),
        ),
    ]);
  }
}

class _StockChart extends CustomPainter {
  _StockChart(this.series, this.days, this.today);
  final List<({Color color, List<double?> points})> series;
  final int days;
  final DateTime today;

  @override
  void paint(Canvas c, Size s) {
    const left = 34.0, bottom = 24.0;
    final w = s.width - left, h = s.height - bottom;
    var maxV = 1.0;
    for (final x in series) {
      for (final v in x.points) {
        if (v != null) maxV = math.max(maxV, v);
      }
    }
    maxV = (maxV * 1.12).ceilToDouble();
    final grid = Paint()..color = B.line;
    void label(String t, Offset o, {TextAlign align = TextAlign.left, Color color = B.mute}) {
      final tp = TextPainter(text: TextSpan(text: t, style: B.mono(10, color: color, spacing: 0)), textDirection: TextDirection.ltr, textAlign: align)..layout(minWidth: 30, maxWidth: 60);
      tp.paint(c, o);
    }

    for (var i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      c.drawLine(Offset(left, y), Offset(s.width, y), grid);
      label('${(maxV * i / 4).round()}', Offset(0, y - 6));
    }
    double px(int i) => left + w * i / (days - 1);
    double py(double v) => h - h * v / maxV;

    // Today is always marked.
    final todayPaint = Paint()
      ..color = B.gold.withValues(alpha: .6)
      ..strokeWidth = 1.2;
    c.drawLine(Offset(px(days - 1), 0), Offset(px(days - 1), h), todayPaint);
    final step = days <= 7 ? 1 : 7;
    for (var i = days - 1; i >= 0; i -= step) {
      final d = today.subtract(Duration(days: days - 1 - i));
      final name = i == days - 1 ? 'today' : (days <= 7 ? dayName(d).substring(0, 3) : '${d.day}/${d.month}');
      label(name, Offset(px(i) - (i == days - 1 ? 30 : 14), h + 7), color: i == days - 1 ? B.gold : B.mute);
    }

    for (final x in series) {
      final path = Path();
      var started = false;
      for (var i = 0; i < x.points.length; i++) {
        final v = x.points[i];
        if (v == null) continue;
        final o = Offset(px(i), py(v));
        if (!started) {
          path.moveTo(o.dx, o.dy);
          started = true;
        } else {
          path.lineTo(o.dx, o.dy);
        }
        c.drawCircle(o, 2.4, Paint()..color = x.color);
      }
      c.drawPath(
        path,
        Paint()
          ..color = x.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StockChart o) => true;
}

// ======================= Constellation =======================
class _Constellation extends StatefulWidget {
  const _Constellation({required this.repo});
  final ShopRepo repo;

  @override
  State<_Constellation> createState() => _ConstellationState();
}

class _ConstellationState extends State<_Constellation> {
  final _fx = FxController();
  double _horizon = 0;
  String? _selected;
  int _sig = -1;

  /// Variants of one product are linked, and so is anything bought on the same market trip.
  List<List<String>> _links() {
    final r = widget.repo;
    final out = <List<String>>[];
    final byGroup = <String, List<String>>{};
    for (final p in r.products) {
      (byGroup[p.group] ??= []).add(p.id);
    }
    for (final g in byGroup.values) {
      for (var i = 1; i < g.length; i++) {
        out.add([g[0], g[i]]);
      }
    }
    final trips = <DateTime, Set<String>>{};
    for (final l in r.logs.where((l) => l.type == 'restock')) {
      (trips[dayOnly(l.at)] ??= {}).add(l.product);
    }
    final seen = <String>{};
    for (final t in trips.values) {
      final a = t.toList()..sort();
      for (var i = 0; i < a.length; i++) {
        for (var j = i + 1; j < a.length; j++) {
          if (seen.add('${a[i]}|${a[j]}') && seen.length <= 40) out.add([a[i], a[j]]);
        }
      }
    }
    return out;
  }

  void _push() {
    final r = widget.repo;
    final sig = Object.hashAll(r.rows.map((x) => Object.hash(x.$1.id, x.$2.stock, x.$2.meanDaily)));
    if (sig == _sig) return;
    _sig = sig;
    _fx.send({
      'items': [
        for (final (p, f) in r.rows)
          {
            'id': p.id,
            'name': p.label,
            'group': p.group,
            'velocity': f.meanDaily,
            'daysLeft': f.stock <= 0 && f.daysOfData > 0 ? 0 : f.daysLeft,
            'warnDays': f.meanDaily > 0 ? f.warningLevel / f.meanDaily : 2,
            'important': f.isLow,
          }
      ],
      'links': _links(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.repo;
    _push();
    final sel = _selected == null ? null : r.products.where((p) => p.id == _selected).firstOrNull;
    if (r.products.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('Add products and each one becomes a star here.', textAlign: TextAlign.center, style: B.body(15, color: B.mute))));
    }
    final date = r.today.add(Duration(days: _horizon.round()));
    final goneBy = [for (final (p, f) in r.rows) if (f.daysLeft != null && f.daysLeft! <= _horizon) p.label];
    return Stack(children: [
      Positioned.fill(
        child: FxView(
          kind: 'nodes',
          controller: _fx,
          onEvent: (e) {
            if (e['name'] == 'select') setState(() => _selected = e['id']);
            if (e['name'] == 'clear') setState(() => _selected = null);
          },
          fallback: Center(child: Text('Your phone can\'t show this view. The chart has the same numbers.', textAlign: TextAlign.center, style: B.body(14, color: B.mute))),
        ),
      ),
      Positioned(
        left: 14,
        right: 14,
        bottom: 12,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                color: B.surface.withValues(alpha: .92),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => openProduct(context, r, sel.id),
                child: Row(children: [
                  Expanded(child: Text(sel.label, style: B.body(16, w: FontWeight.w700))),
                  Pill(daysLeftText(r.forecasts[sel.id]!), color: B.urgency(r.forecasts[sel.id]!.daysLeft, r.forecasts[sel.id]!.isLow)),
                  const Icon(Icons.chevron_right_rounded, color: B.mute),
                ]),
              ),
            ),
          Panel(
            color: B.surface.withValues(alpha: .9),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(_horizon.round() == 0 ? 'Today. Drag to see the days ahead.' : '${dayName(date)} ${date.day}/${date.month}: ${goneBy.isEmpty ? 'nothing has run out' : '${goneBy.length} run out${goneBy.length <= 2 ? ' (${goneBy.join(', ')})' : ''}'}', style: B.body(14, w: FontWeight.w600)),
              Slider(
                value: _horizon,
                min: 0,
                max: 14,
                divisions: 14,
                activeColor: B.gold,
                onChanged: (v) {
                  setState(() => _horizon = v);
                  _fx.send({'horizon': v});
                },
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
