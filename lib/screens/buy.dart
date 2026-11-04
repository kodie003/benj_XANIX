import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/forecast.dart';
import '../core/repo.dart';
import 'product.dart';
import 'shell.dart';
import 'ui.dart';

/// F5 weekly buying list, with F6 (calendar adjustment shown) and F12 (cash budget).
class BuyScreen extends StatefulWidget {
  const BuyScreen({super.key, required this.repo, required this.shell});
  final ShopRepo repo;
  final ShellState shell;

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  final _cash = TextEditingController();

  @override
  Widget build(BuildContext context) {
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

    if (repo.products.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        Empty(icon: Icons.shopping_basket_outlined, text: 'Add products and log for a few days. Your weekly buying list will appear here.'),
      ]);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 220), children: [
      Text('To buy this week', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      Text(restockDay == null ? 'Enough to last until next week.' : 'Enough to last until ${weekdays[restockDay - 1]}.', style: text.bodyMedium),
      const SizedBox(height: 12),
      TextField(
        controller: _cash,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Cash for restocking (optional)',
          prefixText: 'GHS ',
          helperText: 'benj puts the most urgent items first and stops where the cash runs out.',
          border: OutlineInputBorder(),
        ),
      ),
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
            onPressed: () => widget.shell.go(1, logMode: 'restock'),
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
