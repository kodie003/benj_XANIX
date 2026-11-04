import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/repo.dart';
import 'product_form.dart';
import 'ui.dart';

void openProduct(BuildContext context, ShopRepo repo, Product p) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductScreen(repo: repo, productId: p.id)));

/// Product detail (PRD section 8): stock, warning level, F7 forecast vs actual by week,
/// and recent logs (which can be removed if entered by mistake).
class ProductScreen extends StatelessWidget {
  const ProductScreen({super.key, required this.repo, required this.productId});
  final ShopRepo repo;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final p = repo.products.where((x) => x.id == productId).firstOrNull;
        if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('This product was removed.')));
        final f = repo.forecasts[p.id]!;
        final logs = repo.logsFor(p.id).reversed.take(15).toList();
        final checks = weekChecks(p, repo.logsFor(p.id), repo.events, repo.today);
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(p.label),
            actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => showProductForm(context, repo, editing: p)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Delete ${p.label}?'),
                      content: const Text('It will disappear from your lists. Its past logs stay in your records.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await repo.deleteProduct(p.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Stat('On the shelf', units(p, f.stock), color: urgencyColor(context, f)),
              _Stat('Sells per day', f.learning ? 'learning' : qty(double.parse(f.meanDaily.toStringAsFixed(1)))),
              _Stat('Days left', daysLeftText(f) ?? '–'),
            ]),
            Section(
              title: 'Warning level',
              child: Card(
                child: ListTile(
                  title: Text('Warn me at ${units(p, f.warningLevel)}'),
                  subtitle: Text(p.warningLevel == null
                      ? (f.learning ? "benj will suggest a level after 3 days of logs." : "benj's suggestion: covers sales until your next restock in ${f.leadDays} days, with a safety buffer.")
                      : 'You set this. benj would suggest ${units(p, f.suggestedWarning)}.'),
                  trailing: TextButton(onPressed: () => showProductForm(context, repo, editing: p), child: const Text('Change')),
                ),
              ),
            ),
            Section(
              title: 'Was benj right? (forecast vs actual)',
              child: checks.isEmpty
                  ? Text('After a full week with at least 3 days of logs before it, benj shows here what it predicted and what really sold.', style: text.bodyMedium)
                  : Card(
                      child: Table(
                        columnWidths: const {0: FlexColumnWidth(1.4)},
                        children: [
                          _row(context, ['Week of', 'Predicted', 'Sold', 'Off by'], header: true),
                          for (final c in checks)
                            _row(context, [
                              '${c.weekStart.day}/${c.weekStart.month}',
                              qty(c.predicted.round()),
                              qty(c.actual.round()),
                              '${(c.error * 100).round()}%',
                            ]),
                        ],
                      ),
                    ),
            ),
            Section(
              title: 'Recent logs',
              child: logs.isEmpty
                  ? const Text('No logs yet.')
                  : Card(
                      child: Column(children: [
                        for (final l in logs)
                          ListTile(
                            dense: true,
                            leading: Icon(switch (l.type) { 'sale' => Icons.sell_outlined, 'restock' => Icons.add_shopping_cart, _ => Icons.fact_check_outlined }),
                            title: Text(switch (l.type) {
                              'sale' => 'Sold ${units(p, l.quantity)}',
                              'restock' => 'Bought ${units(p, l.quantity)}${l.unitPrice == null ? '' : ' at ${cedis(l.unitPrice!)}'}',
                              _ => l.method == 'setup' ? 'Started with ${units(p, l.quantity)}' : 'Counted ${units(p, l.quantity)}',
                            }),
                            subtitle: Text('${weekdays[l.at.weekday - 1].substring(0, 3)} ${l.at.day}/${l.at.month}, ${l.at.hour.toString().padLeft(2, '0')}:${l.at.minute.toString().padLeft(2, '0')}'),
                            trailing: IconButton(icon: const Icon(Icons.close, size: 18), tooltip: 'Remove this log', onPressed: () => repo.deleteLog(l.id)),
                          ),
                      ]),
                    ),
            ),
          ]),
        );
      },
    );
  }

  TableRow _row(BuildContext context, List<String> cells, {bool header = false}) => TableRow(children: [
        for (final c in cells)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(c, style: header ? const TextStyle(fontWeight: FontWeight.w700) : null),
          ),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}
