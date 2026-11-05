import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repo.dart';
import 'product_form.dart';
import 'ui.dart';

/// Entering stock. The Log tab has Sold (tap +/- per product) and Count (type what's on the
/// shelf), F2. The Buy tab uses this for I bought (quantity and price), F3.
/// Seconds per entry are recorded, because logging is the riskiest assumption (PRD 4).
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.repo, this.initialMode = 'sale', this.modes = const ['sale', 'count']});
  final ShopRepo repo;
  final String initialMode;

  /// The kinds of entry on offer; with only one, there is nothing to switch.
  final List<String> modes;

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
    'sale': ('Sold', 'Tap + for each one sold today.', 'Sales sent'),
    'count': ('Count', 'Type how many are on the shelf right now.', 'Counts sent'),
    'restock': ('Bought', 'Tap + for what you bought, then add the price.', 'Purchases sent'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_modes[_mode]!.$3}: ${list.length} ${list.length == 1 ? 'item' : 'items'}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final n = _entries().length;
    return Column(children: [
      if (widget.modes.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<String>(
            segments: [for (final m in widget.modes) ButtonSegment(value: m, label: Text(_modes[m]!.$1))],
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
                if (repo.categories.isEmpty)
                  for (final p in repo.products) _row(p)
                else
                  for (final (name, list) in groupByCategory(repo.products)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    for (final p in list) _row(p),
                  ],
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
                child: Padding(padding: const EdgeInsets.all(14), child: Text(n == 0 ? 'Nothing to send yet' : 'Send $n ${n == 1 ? 'item' : 'items'}')),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _row(Product p) {
    final f = widget.repo.forecasts[p.id];
    final onList = _mode == 'restock' && f != null && f.suggestedQty > 0 ? ' · on your list: ${f.suggestedQty}' : '';
    final onShelf = f == null ? '' : 'On the shelf: ${units(p, f.stock)}$onList';
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
