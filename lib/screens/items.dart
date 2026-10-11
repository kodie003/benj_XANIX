import 'package:flutter/material.dart';

import '../models.dart';

/// Item list with stock on hand and profit per unit (PRD "Items" screen).
class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in state.items)
          Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text('Sell GHS ${item.price.toStringAsFixed(0)} - you keep GHS '
                  '${(item.price - item.cost).toStringAsFixed(0)} per ${item.unit}'
                  '${item.perishable ? ' - made fresh' : ' - reorder at ${item.reorder.toStringAsFixed(0)}'}'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(state.onHand(item.id).toStringAsFixed(0), style: Theme.of(context).textTheme.titleLarge),
                const Text('in stock'),
              ]),
            ),
          ),
        if (state.items.isEmpty) const Text('No items yet. Add everything you sell, with what you pay and what you charge.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add an item'),
          onPressed: () => showDialog(context: context, builder: (_) => _AddItemDialog(state: state)),
        ),
        const Divider(height: 32),
        // R7: the owner knows their own rhythm (school breaks, market days, festivals).
        Text('Busy or quiet days coming up', style: Theme.of(context).textTheme.titleMedium),
        for (final e in state.events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e['name']),
            subtitle: Text('From ${e['start']} - expect ${((e['effect'] as num) * 100).round().abs()}% '
                '${(e['effect'] as num) < 0 ? 'fewer' : 'more'} customers'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => state.removeEvent(e)),
          ),
        if (state.events.isEmpty) const Text('e.g. school break, exams, a festival. SeeYou adjusts your advice the week before.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: const Text('Add a busy or quiet day'),
          onPressed: () => showDialog(context: context, builder: (_) => _AddEventDialog(state: state)),
        ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({required this.state});
  final AppState state;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _name = TextEditingController();
  final _unit = TextEditingController(text: 'piece');
  final _cost = TextEditingController();
  final _price = TextEditingController();
  final _reorder = TextEditingController(text: '0');
  final _opening = TextEditingController();
  bool _perishable = false;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label, {bool number = false}) => TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : null,
          decoration: InputDecoration(labelText: label),
        );
    return AlertDialog(
      title: const Text('Add an item'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          field(_name, 'Name (e.g. Gari 1 kg)'),
          field(_unit, 'Unit (bag, plate, piece...)'),
          field(_cost, 'What you pay for one (GHS)', number: true),
          field(_price, 'What you sell one for (GHS)', number: true),
          field(_reorder, 'Buy more when only this many are left', number: true),
          field(_opening, 'How many do you have right now?', number: true),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _perishable,
            onChanged: (v) => setState(() => _perishable = v!),
            title: const Text('Made or bought fresh each day'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final cost = double.tryParse(_cost.text), price = double.tryParse(_price.text);
            if (_name.text.trim().isEmpty || cost == null || price == null) return;
            widget.state.addItem(Item(
              id: '${_name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}',
              name: _name.text.trim(),
              unit: _unit.text.trim().isEmpty ? 'piece' : _unit.text.trim(),
              cost: cost,
              price: price,
              reorder: double.tryParse(_reorder.text) ?? 0,
              perishable: _perishable,
            ), double.tryParse(_opening.text) ?? 0);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog({required this.state});
  final AppState state;

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  final _name = TextEditingController();
  final _percent = TextEditingController();
  DateTime? _start;
  bool _fewer = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Busy or quiet day'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'What is happening?')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_start == null ? 'Pick the start date' : 'Starts ${isoDay(_start!)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)));
              if (d != null) setState(() => _start = d);
            },
          ),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('Fewer customers')), ButtonSegment(value: false, label: Text('More'))],
            selected: {_fewer},
            onSelectionChanged: (v) => setState(() => _fewer = v.first),
          ),
          TextField(
            controller: _percent,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'By about how much?', suffixText: '%'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final pct = double.tryParse(_percent.text);
            if (_name.text.trim().isEmpty || _start == null || pct == null) return;
            widget.state.addEvent({'name': _name.text.trim(), 'start': isoDay(_start!), 'effect': (_fewer ? -pct : pct) / 100});
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
