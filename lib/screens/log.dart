import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repo.dart';
import 'product_form.dart';
import 'ui.dart';

/// F2 quick stock log and F3 restock entry, on one screen.
/// Sold: tap +/- per product. Count: type what's on the shelf. Bought: quantity and price.
/// Seconds per entry are recorded, because logging is the riskiest assumption (PRD 4).
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.repo, this.initialMode = 'sale'});
  final ShopRepo repo;
  final String initialMode;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late String _mode = widget.initialMode;
  final _qty = <String, double>{};
  final _count = <String, TextEditingController>{};
  final _price = <String, TextEditingController>{};
  DateTime? _started;
  bool _typed = false;

  static const _modes = {
    'sale': ('Sold', 'Tap + for each one sold today.'),
    'count': ('Count', 'Type how many are on the shelf right now.'),
    'restock': ('Bought', 'What did you buy at the market?'),
  };

  void _touch() => _started ??= DateTime.now();

  TextEditingController _ctl(Map<String, TextEditingController> m, String id) => m.putIfAbsent(id, () => TextEditingController()..addListener(() => setState(() {})));

  List<StockLog> _entries() {
    final now = DateTime.now();
    final secs = _started == null ? null : now.difference(_started!).inSeconds;
    final method = _typed ? 'type' : 'tap';
    final out = <StockLog>[];
    for (final p in widget.repo.products) {
      if (_mode == 'count') {
        final v = double.tryParse(_ctl(_count, p.id).text.trim());
        if (v != null && v >= 0) out.add(StockLog(product: p.id, at: now, type: 'count', quantity: v, method: 'type', secondsTaken: secs));
      } else {
        final q = _qty[p.id] ?? 0;
        if (q <= 0) continue;
        final price = _mode == 'restock' ? double.tryParse(_ctl(_price, p.id).text.trim()) : null;
        out.add(StockLog(product: p.id, at: now, type: _mode, quantity: q, unitPrice: price, method: method, secondsTaken: secs));
      }
    }
    return out;
  }

  Future<void> _save() async {
    final list = _entries();
    if (list.isEmpty) return;
    await widget.repo.addLogs(list);
    setState(() {
      _qty.clear();
      for (final c in [..._count.values, ..._price.values]) {
        c.clear();
      }
      _started = null;
      _typed = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${list.length} ${list.length == 1 ? 'item' : 'items'}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final n = _entries().length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SegmentedButton<String>(
          segments: [for (final e in _modes.entries) ButtonSegment(value: e.key, label: Text(e.value.$1))],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Align(alignment: Alignment.centerLeft, child: Text(_modes[_mode]!.$2, style: Theme.of(context).textTheme.titleMedium)),
      ),
      Expanded(
        child: repo.products.isEmpty
            ? ListView(padding: const EdgeInsets.all(16), children: [
                Empty(icon: Icons.inventory_2_outlined, text: 'Add the products you sell first.', action: 'Add a product', onAction: () => showProductForm(context, repo)),
              ])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 200), children: [
                for (final p in repo.products) _row(p),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => showProductForm(context, repo), icon: const Icon(Icons.add), label: const Text('Add a product')),
              ]),
      ),
      if (repo.products.isNotEmpty)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: n == 0 ? null : _save,
                child: Padding(padding: const EdgeInsets.all(14), child: Text(n == 0 ? 'Nothing to save yet' : 'Save $n ${n == 1 ? 'item' : 'items'}')),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _row(Product p) {
    final f = widget.repo.forecasts[p.id];
    final onShelf = f == null ? '' : 'On the shelf: ${units(p, f.stock)}';
    final q = _qty[p.id] ?? 0;
    final text = Theme.of(context).textTheme;
    Widget stepper() => Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton.filledTonal(
            tooltip: 'One less ${p.label}',
            onPressed: q <= 0
                ? null
                : () => setState(() {
                      _touch();
                      _qty[p.id] = q - 1;
                    }),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(width: 36, child: Text(qty(q), textAlign: TextAlign.center, style: text.titleLarge)),
          IconButton.filled(
            tooltip: 'One more ${p.label}',
            onPressed: () => setState(() {
              _touch();
              _qty[p.id] = q + 1;
            }),
            icon: const Icon(Icons.add),
          ),
        ]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (onShelf.isNotEmpty) Text(onShelf, style: text.bodySmall),
              ]),
            ),
            if (_mode == 'count')
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _ctl(_count, p.id),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    _touch();
                    _typed = true;
                  },
                  decoration: InputDecoration(labelText: 'Count', suffixText: p.plural(2), border: const OutlineInputBorder(), isDense: true),
                ),
              )
            else
              stepper(),
          ]),
          if (_mode == 'restock' && q > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _ctl(_price, p.id),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price per ${p.unit} (GHS)',
                  hintText: p.costPrice == null ? 'optional' : qty(p.costPrice!),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
