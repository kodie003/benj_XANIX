import 'package:flutter/material.dart';

import '../models.dart';
import '../templates.dart';

/// Onboarding: name the business, pick a template, enter today's opening stock.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _owner = TextEditingController();
  String _type = templates.keys.first;
  late List<Item> _items = _copy(_type);
  final Map<String, TextEditingController> _opening = {};

  List<Item> _copy(String type) => [for (final i in templates[type]!) Item.fromJson(i.toJson())];

  TextEditingController _openingFor(String id) => _opening.putIfAbsent(id, TextEditingController.new);

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your business a name first')));
      return;
    }
    await widget.state.setUp(
      {'name': _name.text.trim(), 'owner': _owner.text.trim(), 'type': _type},
      _items,
      {for (final i in _items) i.id: double.tryParse(_openingFor(i.id).text) ?? 0},
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('SeeYou')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your business already tells a story every day.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Write down what you sell at the end of the day - like your tally book. '
            'Every week SeeYou tells you 3 things to do: what to buy, what to make less of, and what to re-price.',
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: const Text('Just looking? Open the demo shop'),
              subtitle: const Text("4 weeks of Auntie Esi's provisions & waakye records"),
              trailing: state.loading ? const CircularProgressIndicator() : const Icon(Icons.arrow_forward),
              onTap: state.loading ? null : state.loadDemo,
            ),
          ),
          if (state.error != null) Text(state.error!, style: const TextStyle(color: Colors.red)),
          const Divider(height: 32),
          Text('Or set up your own', style: Theme.of(context).textTheme.titleMedium),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Business name')),
          TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Your name (for your weekly message)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'What do you sell?'),
            items: [for (final t in templates.keys) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (t) => setState(() {
              _type = t!;
              _items = _copy(t);
            }),
          ),
          const SizedBox(height: 16),
          if (_items.isNotEmpty) const Text('How many of each do you have right now? (leave empty if none)'),
          for (final item in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              subtitle: Text('Buy GHS ${item.cost.toStringAsFixed(0)} - sell GHS ${item.price.toStringAsFixed(0)} per ${item.unit}'),
              trailing: SizedBox(
                width: 90,
                child: TextField(
                  controller: _openingFor(item.id),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: '0', suffixText: item.unit),
                ),
              ),
            ),
          if (_items.isEmpty) const Text('You can add your items on the Items tab after this step.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _start, child: const Padding(padding: EdgeInsets.all(12), child: Text('Start'))),
        ],
      ),
    );
  }
}
