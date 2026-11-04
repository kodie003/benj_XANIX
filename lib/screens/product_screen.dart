import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import 'product_form.dart';

Future<void> openProduct(BuildContext context, ShopRepo repo, String id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ProductScreen(repo: repo, id: id)));

/// F4 and F7: how benj reached its answer, whether it was right, and the owner's override.
class _ProductScreen extends StatelessWidget {
  const _ProductScreen({required this.repo, required this.id});
  final ShopRepo repo;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final p = repo.products.where((x) => x.id == id).firstOrNull;
          if (p == null) return const Scaffold();
          final f = repo.forecasts[id]!;
          final logs = repo.logsFor(id);
          final checks = weekChecks(p, logs, repo.events, repo.today);
          final recent = logs.reversed.take(12).toList();
          final color = f.learning ? B.mute : B.urgency(f.daysLeft, f.isLow);
          return Scaffold(
            appBar: AppBar(
              title: Text(p.label),
              actions: [IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded), onPressed: () => openProductForm(context, repo, existing: p))],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${tidy(f.stock)}', style: B.display(64, color: color)),
                    const SizedBox(width: 8),
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${p.plural(f.stock)} on hand', style: B.body(16, color: B.mute))),
                    const Spacer(),
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Pill(f.learning ? 'Still learning' : daysLeftText(f), color: color)),
                  ]),
                  const SizedBox(height: 14),
                  _Working(p: p, f: f),
                  const SizedBox(height: 12),
                  _WarningEditor(repo: repo, p: p, f: f),
                  const SizedBox(height: 20),
                  Text('Was benj right?', style: B.display(21)),
                  const SizedBox(height: 4),
                  Text('Each week: what I would have predicted, against what really left the shelf.', style: B.body(14, color: B.mute)),
                  const SizedBox(height: 10),
                  if (checks.isEmpty)
                    Panel(child: Text('Nothing to compare yet. This fills in after a full week of logs.', style: B.body(14, color: B.mute)))
                  else
                    Panel(child: Column(children: [for (final c in checks) _CheckRow(c, checks.map((x) => math.max(x.predicted, x.actual)).reduce(math.max))])),
                  const SizedBox(height: 20),
                  Text('Recent logs', style: B.display(21)),
                  const SizedBox(height: 6),
                  if (recent.isEmpty) Text('No logs yet.', style: B.body(14, color: B.mute)),
                  for (final l in recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(l.method == 'voice' ? Icons.mic_rounded : (l.method == 'photo' ? Icons.photo_camera_rounded : Icons.touch_app_rounded), size: 18, color: B.mute),
                      title: Text('${{'sale': 'Sold', 'count': 'Counted', 'restock': 'Bought'}[l.type]} ${tidy(l.quantity)}', style: B.body(15, w: FontWeight.w600)),
                      subtitle: Text('${dayName(l.at)} ${l.at.day}/${l.at.month}, ${l.at.hour.toString().padLeft(2, '0')}:${l.at.minute.toString().padLeft(2, '0')}', style: B.body(12.5, color: B.mute)),
                      trailing: IconButton(tooltip: 'Delete this log', icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: () => repo.deleteLog(l.id)),
                    ),
                  const SizedBox(height: 20),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: B.coral),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: Text('Remove ${p.label}?', style: B.display(20)),
                          content: Text('It disappears from your lists. Past logs stay in your records.', style: B.body(14, color: B.mute)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep it')),
                            TextButton(onPressed: () => Navigator.pop(d, true), style: TextButton.styleFrom(foregroundColor: B.coral), child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        Navigator.of(context).pop();
                        repo.deleteProduct(p.id);
                      }
                    },
                    child: const Text('Remove this product'),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

/// No black box: every number can be explained out loud to a judge or an owner.
class _Working extends StatelessWidget {
  const _Working({required this.p, required this.f});
  final Product p;
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(a, style: B.body(14, color: B.mute))), Text(b, style: B.body(14.5, w: FontWeight.w700))]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('HOW I WORKED THIS OUT', style: B.mono(11, color: B.gold)),
        const SizedBox(height: 8),
        row('You sell per day (last ${f.daysOfData} days)', f.meanDaily.toStringAsFixed(1)),
        row('Busy-day swing', '±${f.sdDaily.toStringAsFixed(1)}'),
        row('Calendar adjustment', f.factor == 1 ? 'none' : '×${f.factor.toStringAsFixed(2)}'),
        row('Needed for 7 days, with a safety buffer', '${tidy((f.weekDemand + kZ * f.sdDaily * math.sqrt(7)).ceilToDouble())}'),
        row('Days until your next restock', '${f.leadDays}'),
        const Divider(color: B.line, height: 18),
        row('So buy', f.suggestedQty == 0 ? 'nothing this week' : '${f.suggestedQty} ${p.plural(f.suggestedQty)}'),
        if (f.learning) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Only ${f.daysOfData} day${f.daysOfData == 1 ? '' : 's'} of logs so far, so treat this as a rough start.', style: B.body(13, color: B.gold))),
      ]),
    );
  }
}

class _WarningEditor extends StatefulWidget {
  const _WarningEditor({required this.repo, required this.p, required this.f});
  final ShopRepo repo;
  final Product p;
  final Forecast f;

  @override
  State<_WarningEditor> createState() => _WarningEditorState();
}

class _WarningEditorState extends State<_WarningEditor> {
  late final _c = TextEditingController(text: widget.p.warningLevel == null ? '' : '${tidy(widget.p.warningLevel!)}');

  void _set(double? v) {
    final p = widget.p;
    widget.repo.saveProduct(Product(id: p.id, name: p.name, unit: p.unit, size: p.size, costPrice: p.costPrice, sellPrice: p.sellPrice, warningLevel: v));
  }

  @override
  Widget build(BuildContext context) => Panel(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Warn me at', style: B.body(15, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.p.warningLevel == null ? 'Using my suggestion: ${widget.f.suggestedWarning}' : 'My suggestion is ${widget.f.suggestedWarning}', style: B.body(13, color: B.mute)),
              if (widget.p.warningLevel != null)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 32)),
                  onPressed: () {
                    _c.clear();
                    _set(null);
                  },
                  child: const Text('Use your suggestion'),
                ),
            ]),
          ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: B.display(22),
              decoration: InputDecoration(hintText: '${widget.f.suggestedWarning}', isDense: true),
              onChanged: (v) => _set(double.tryParse(v)),
            ),
          ),
        ]),
      );
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.c, this.maxV);
  final WeekCheck c;
  final double maxV;

  @override
  Widget build(BuildContext context) {
    final good = c.error <= 0.2;
    Widget bar(double v, Color col) => LayoutBuilder(
          builder: (_, b) => Align(
            alignment: Alignment.centerLeft,
            child: Container(height: 8, width: maxV == 0 ? 0 : b.maxWidth * v / maxV, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4))),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 52, child: Text('${c.weekStart.day}/${c.weekStart.month}', style: B.mono(12))),
        Expanded(
          child: Column(children: [
            Row(children: [Expanded(child: bar(c.predicted, B.violet)), SizedBox(width: 44, child: Text(c.predicted.toStringAsFixed(0), textAlign: TextAlign.right, style: B.mono(11, color: B.violet)))]),
            const SizedBox(height: 4),
            Row(children: [Expanded(child: bar(c.actual, B.teal)), SizedBox(width: 44, child: Text(c.actual.toStringAsFixed(0), textAlign: TextAlign.right, style: B.mono(11, color: B.teal)))]),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 58, child: Pill('${(c.error * 100).round()}%', color: good ? B.teal : B.gold)),
      ]),
    );
  }
}
