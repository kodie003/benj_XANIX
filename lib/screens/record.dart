import 'package:flutter/material.dart';

import '../models.dart';

/// FR-B2: end-of-day bulk entry. One screen, one number per item - like the paper tally.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.state});
  final AppState state;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  static const _modes = {
    'sale': ('Sold', 'How many did you sell today?'),
    'received': ('Bought / made', 'How many did you buy or prepare today?'),
    'waste': ('Thrown away', 'How many spoiled, expired or were left over?'),
  };
  String _mode = 'sale';
  final Map<String, TextEditingController> _qty = {};
  final Map<String, TextEditingController> _cost = {};

  TextEditingController _ctl(Map<String, TextEditingController> m, String id) => m.putIfAbsent(id, TextEditingController.new);

  Future<void> _save() async {
    final today = isoDay(DateTime.now());
    final list = <Movement>[];
    for (final item in widget.state.items) {
      final q = double.tryParse(_ctl(_qty, item.id).text) ?? 0;
      if (q <= 0) continue;
      final cost = _mode == 'received' ? double.tryParse(_ctl(_cost, item.id).text) : null;
      list.add(Movement(item.id, _mode, q, today, cost: cost));
    }
    if (list.isEmpty) return;
    await widget.state.addMovements(list);
    for (final c in [..._qty.values, ..._cost.values]) {
      c.clear();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${list.length} items. Your actions are updating.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: [for (final e in _modes.entries) ButtonSegment(value: e.key, label: Text(e.value.$1))],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 12),
        Text(_modes[_mode]!.$2, style: Theme.of(context).textTheme.titleMedium),
        if (_mode == 'received') const Text('If the market price changed, type the new price you paid.'),
        for (final item in state.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text('In stock: ${state.onHand(item.id).toStringAsFixed(0)} - '
                'recorded today: ${state.recordedToday(item.id, _mode).toStringAsFixed(0)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_mode == 'received')
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _ctl(_cost, item.id),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: item.cost.toStringAsFixed(0), prefixText: 'GHS '),
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _ctl(_qty, item.id),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: '0', suffixText: item.unit),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text("Save today's tally"))),
      ],
    );
  }
}
