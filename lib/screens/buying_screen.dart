import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/forecast.dart';
import '../core/models.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import 'log_screen.dart';
import 'product_screen.dart';

/// F5 and F12. Answers "what should I buy this week, and how much?", and when cash is
/// short, buys what is most at risk first. Late payments squeeze restock money.
class BuyingScreen extends StatefulWidget {
  const BuyingScreen({super.key, required this.repo});
  final ShopRepo repo;

  @override
  State<BuyingScreen> createState() => _BuyingScreenState();
}

class _BuyingScreenState extends State<BuyingScreen> {
  final _cash = TextEditingController();
  final _edits = <String, int>{};
  final _bought = <String>{};

  ShopRepo get r => widget.repo;

  String _shareText(List<({Product product, Forecast f, int buy, double cost})> plan) {
    final b = StringBuffer('benj buying list for ${r.shop?.name ?? 'my shop'}\n');
    for (final x in plan) {
      final q = _edits[x.product.id] ?? x.buy;
      if (q > 0) b.writeln('• $q ${x.product.plural(q)} of ${x.product.label}');
    }
    return b.toString();
  }

  Future<void> _recordBought(List<({Product product, Forecast f, int buy, double cost})> plan) async {
    final now = DateTime.now();
    final list = [
      for (final x in plan)
        if (_bought.contains(x.product.id) && (_edits[x.product.id] ?? x.buy) > 0)
          StockLog(product: x.product.id, at: now, type: 'restock', quantity: (_edits[x.product.id] ?? x.buy).toDouble(), unitPrice: x.product.costPrice, method: 'tap'),
    ];
    if (list.isEmpty) return;
    await saveWithGlow(context, r.addLogs(list), 'Restock recorded. Your stock is up to date.');
    setState(_bought.clear);
  }

  @override
  Widget build(BuildContext context) {
    final cash = double.tryParse(_cash.text);
    final ready = r.rows.where((x) => !x.$2.learning).toList();
    final learning = r.rows.where((x) => x.$2.learning).toList();
    final plan = budgetPlan(ready, cash);
    final total = plan.fold<double>(0, (s, x) => s + (_edits[x.product.id] ?? x.buy) * (x.product.costPrice ?? 0));
    final noPrice = plan.where((x) => x.product.costPrice == null).length;
    final restock = r.shop?.restockDay;
    final activeEvents = r.events.where((e) => !e.end.isBefore(r.today) && e.start.isBefore(r.today.add(const Duration(days: 8)))).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
      children: [
        Text('This week\'s list', style: B.display(28)),
        const SizedBox(height: 2),
        Text(restock == null ? 'Worked out from your own logs.' : 'For your next market day, ${dayName(DateTime(2024, 1, restock))}.', style: B.body(14, color: B.mute)),
        const SizedBox(height: 12),
        TextField(
          controller: _cash,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: B.body(17, w: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'Cash for restock (optional)', prefixText: 'GH₵ ', helperText: 'Short on cash? I\'ll put what runs out first at the top.'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        for (final e in activeEvents)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              color: B.violet.withValues(alpha: .13),
              border: B.violet.withValues(alpha: .35),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.event_rounded, color: B.violet, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('${e.name}: planning for ${e.factor >= 1 ? '${((e.factor - 1) * 100).round()}% more' : '${((1 - e.factor) * 100).round()}% fewer'} customers', style: B.body(14, w: FontWeight.w600))),
              ]),
            ),
          ),
        if (plan.isEmpty && learning.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Text('Add products and log a few days. Your list will appear here.', textAlign: TextAlign.center, style: B.body(15, color: B.mute))),
        if (plan.isEmpty && ready.isNotEmpty) Panel(child: Text('Nothing to buy this week. You have enough for the next 7 days.', style: B.body(15, w: FontWeight.w600, color: B.teal))),
        for (final x in plan) _row(x, cash),
        if (plan.isNotEmpty) ...[
          const SizedBox(height: 6),
          if (total > 0)
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(child: Text(noPrice > 0 ? 'Known cost ($noPrice without a price)' : 'Total cost', style: B.body(14, color: B.mute))),
                Text('GH₵ ${tidy(total)}', style: B.display(21, color: cash != null && total > cash ? B.coral : B.text)),
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('WhatsApp'),
                onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareText(plan))}')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _bought.isEmpty ? null : () => _recordBought(plan), child: Text(_bought.isEmpty ? 'Tick items' : 'I bought ${_bought.length}'))),
          ]),
        ],
        if (learning.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Still learning', style: B.display(19)),
          const SizedBox(height: 4),
          Text('I need 3 days of logs before I suggest amounts. I won\'t guess.', style: B.body(13.5, color: B.mute)),
          const SizedBox(height: 8),
          for (final (p, f) in learning)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.label, style: B.body(15, w: FontWeight.w600)),
              trailing: Pill('${f.daysOfData} of 3 days', color: B.gold),
              onTap: () => openProduct(context, r, p.id),
            ),
        ],
      ],
    );
  }

  Widget _row(({Product product, Forecast f, int buy, double cost}) x, double? cash) {
    final p = x.product, f = x.f;
    final q = _edits[p.id] ?? x.buy;
    final cut = cash != null && x.buy < f.suggestedQty;
    final ticked = _bought.contains(p.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(6, 10, 10, 12),
        border: ticked ? B.teal.withValues(alpha: .6) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Checkbox(
              value: ticked,
              activeColor: B.teal,
              onChanged: (v) => setState(() => v == true ? _bought.add(p.id) : _bought.remove(p.id)),
            ),
            Expanded(child: GestureDetector(onTap: () => openProduct(context, r, p.id), child: Text(q == 0 && cut ? 'No cash left for ${p.label}' : buyLine(p, q), style: B.display(18.5, height: 1.15, color: q == 0 && cut ? B.mute : B.text)))),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_rounded), onPressed: q <= 0 ? null : () => setState(() => _edits[p.id] = q - 1)),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_rounded), onPressed: () => setState(() => _edits[p.id] = q + 1)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill(daysLeftText(f), color: B.urgency(f.daysLeft, f.isLow)),
              Text('need ${tidy(double.parse(f.weekDemand.toStringAsFixed(1)))}, have ${tidy(f.stock)}', style: B.body(13, color: B.mute)),
              if (f.factor != 1) Text('calendar ×${f.factor.toStringAsFixed(2)}', style: B.body(13, color: B.violet)),
              if (cut && q > 0) Text('reduced to fit your cash', style: B.body(13, color: B.gold, w: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}
