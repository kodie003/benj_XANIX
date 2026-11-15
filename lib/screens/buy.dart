import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../poddy/poddy.dart';
import 'log.dart';
import 'product.dart';
import 'shell.dart';
import 'ui.dart';

typedef BuyPlan = List<({Product product, Forecast f, int buy, double cost})>;

/// Poddy's plan for the cash the owner has: a headline and a few short lines.
/// Worked out from the buying list, so it never invents a number.
({String headline, List<String> lines}) cashAdvice(BuyPlan plan, double cash, {bool learning = false}) {
  if (plan.isEmpty) {
    return learning
        ? (headline: "I'm still learning your shop.", lines: ['Log your sales for 3 days and I will plan your ${cedis(cash)}.'])
        : (headline: 'You have enough of everything this week.', lines: ['Keep your ${cedis(cash)} for next week.']);
  }
  final priced = [for (final r in plan) if ((r.product.costPrice ?? 0) > 0) r];
  final unpriced = [for (final r in plan) if ((r.product.costPrice ?? 0) <= 0) r.product.label];
  if (priced.isEmpty) {
    return (headline: "I can't plan your ${cedis(cash)} yet.", lines: ['Add what you pay for each product, then ask me again.']);
  }
  final afford = [for (final r in priced) if (r.buy > 0) r];
  final spent = priced.fold<double>(0, (s, r) => s + r.cost);
  final short = [for (final r in priced) if (r.buy < r.f.suggestedQty) r];
  final need = short.fold<double>(0, (s, r) => s + (r.f.suggestedQty - r.buy) * r.product.costPrice!);
  final lines = <String>[
    for (final r in afford.take(5)) '${units(r.product, r.buy)} of ${r.product.label}: ${cedis(r.cost)}',
    if (afford.length > 5) 'and ${afford.length - 5} more on the list below',
    if (afford.isNotEmpty) 'That uses ${cedis(spent)}. ${cedis(cash - spent)} is left.',
    if (short.isNotEmpty) 'You need ${cedis(need)} more for ${short.map((r) => r.product.label).join(', ')}.',
    if (unpriced.isNotEmpty) "I can't price ${unpriced.join(', ')}. Add what you pay.",
  ];
  final headline = afford.isEmpty
      ? '${cedis(cash)} is not enough for even one ${priced.first.product.unit} of ${priced.first.product.label}.'
      : short.isEmpty
          ? '${cedis(cash)} covers your whole list.'
          : '${cedis(cash)} will not cover everything. Buy the most urgent first:';
  return (headline: headline, lines: lines);
}

/// F5 weekly buying list, with F6 (calendar adjustment shown) and F12 (cash budget),
/// and F3, recording what was bought, so restocking happens in one place.
class BuyScreen extends StatefulWidget {
  const BuyScreen({super.key, required this.repo, required this.shell, this.startOnBought = false});
  final ShopRepo repo;
  final ShellState shell;
  final bool startOnBought;

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  final _cash = TextEditingController();
  late bool _bought = widget.startOnBought;

  /// The cash amount Poddy last planned for; his plan hides once the amount changes.
  String? _planned;

  void _planCash() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _planned = double.tryParse(_cash.text.trim()) == null ? null : _cash.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    if (repo.products.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        Empty(icon: Icons.shopping_basket_outlined, text: 'Add products and log for a few days. Your weekly buying list will appear here.'),
      ]);
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('To buy')), ButtonSegment(value: true, label: Text('I bought'))],
          selected: {_bought},
          onSelectionChanged: (s) => setState(() => _bought = s.first),
        ),
      ),
      Expanded(child: _bought ? LogScreen(repo: repo, initialMode: 'restock', modes: const ['restock']) : _list(context)),
    ]);
  }

  Widget _advice(BuildContext context, ({String headline, List<String> lines}) a) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(width: 84, height: 96, child: PoddyView(mood: 'present')),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.headline, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final l in a.lines) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $l', style: text.bodyMedium)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final repo = widget.repo;
    final text = Theme.of(context).textTheme;
    final cash = double.tryParse(_cash.text.trim());
    final plan = budgetPlan(repo.rows, cash);
    final learning = repo.rows.where((r) => r.$2.learning).toList();
    final restockDay = repo.shop?.restockDay;
    final total = plan.fold<double>(0, (s, r) => s + r.cost);
    final missingPrice = plan.any((r) => (r.product.costPrice ?? 0) == 0);

    // F6: say which events changed this week's numbers, and by how much.
    final now = repo.today;
    final weekEnd = now.add(const Duration(days: 7));
    final events = repo.events.where((e) => !e.end.isBefore(now) && !e.start.isAfter(weekEnd)).toList();
    final factor = averageFactor(now, 7, repo.events);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 220), children: [
      Text('To buy this week', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      Text(restockDay == null ? 'Enough to last until next week.' : 'Enough to last until ${weekdays[restockDay - 1]}.', style: text.bodyMedium),
      const SizedBox(height: 12),
      TextField(
        controller: _cash,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _planCash(),
        decoration: InputDecoration(
          labelText: 'Cash for restocking (optional)',
          prefixText: 'GHS ',
          helperText: 'Type the cash you have, then press Enter. Poddy plans how to spend it.',
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(icon: const Icon(Icons.send), tooltip: 'Plan my cash', onPressed: cash == null ? null : _planCash),
        ),
      ),
      if (cash != null && _planned == _cash.text.trim()) _advice(context, cashAdvice(plan, cash, learning: learning.length == repo.products.length)),
      if (events.isNotEmpty)
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: ListTile(
            leading: const Icon(Icons.event_note),
            title: Text('Adjusted for ${events.map((e) => e.name).join(', ')}'),
            subtitle: Text(factor >= 1 ? 'About ${((factor - 1) * 100).round()}% more customers expected this week.' : 'About ${((1 - factor) * 100).round()}% fewer customers expected this week.'),
          ),
        ),
      const SizedBox(height: 8),
      if (plan.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(learning.length == repo.products.length ? 'benj is still learning: log for 3 days and your list will appear.' : 'You have enough of everything for this week.', style: text.bodyLarge),
        ),
      for (final r in plan)
        Card(
          child: ListTile(
            onTap: () => openProduct(context, repo, r.product),
            title: Text(
              r.buy > 0 ? buyLine(r.product, r.buy) : 'No cash left for ${r.product.label}',
              style: TextStyle(fontWeight: FontWeight.w700, color: r.buy > 0 ? null : Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(
              '${r.buy < r.f.suggestedQty ? 'Cash covers ${r.buy} of the ${r.f.suggestedQty} you need. ' : ''}'
              'Expect to sell about ${qty(r.f.weekDemand.round())} this week · ${units(r.product, r.f.stock)} on the shelf'
              '${r.cost > 0 ? ' · ${cedis(r.cost)}' : ''}',
            ),
            trailing: Icon(Icons.circle, size: 12, color: urgencyColor(context, r.f)),
          ),
        ),
      if (plan.isNotEmpty) ...[
        if (total > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Total: ${cedis(total)}', style: text.titleMedium)),
        if (missingPrice) Text('Add what you pay for each product to see costs.', style: text.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: () => setState(() => _bought = true),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Record what I bought'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              final lines = [for (final r in plan) if (r.buy > 0) '• ${buyLine(r.product, r.buy)}'];
              final msg = 'benj buying list for ${repo.shop?.name ?? 'my shop'}:\n${lines.join('\n')}';
              launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'));
            },
            icon: const Icon(Icons.share),
            label: const Text('Send to WhatsApp'),
          ),
        ]),
      ],
      if (learning.isNotEmpty && learning.length < repo.products.length)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text('Still learning: ${learning.map((r) => r.$1.label).join(', ')}.', style: text.bodySmall),
        ),
    ]);
  }
}
