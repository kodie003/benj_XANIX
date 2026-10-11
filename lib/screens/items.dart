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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add an item'),
          onPressed: () => showDialog(context: context, builder: (_) => _AddItemDialog(state: state)),
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
            ));
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
