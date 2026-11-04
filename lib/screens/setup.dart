import 'package:flutter/material.dart';

import '../models.dart';
import '../poddy/poddy.dart';

/// Onboarding: just name the business. Items are added by the owner on the Items tab.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.state, this.onSignOut});
  final AppState state;
  final VoidCallback? onSignOut;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _type = TextEditingController();

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your business a name first')));
      return;
    }
    await widget.state.setUp({'name': _name.text.trim(), 'owner': _owner.text.trim(), 'type': _type.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('benj'),
        actions: [if (widget.onSignOut != null) TextButton(onPressed: widget.onSignOut, child: const Text('Sign out'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PoddyCard(mood: 'hello', line: "Hi! I'll help you see what your sales are telling you.", height: 190),
          const SizedBox(height: 16),
          Text('Your business already tells a story every day.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Write down what you sell at the end of the day - like your tally book. '
            'Every week benj tells you 3 things to do: what to buy, what to make less of, and what to re-price.',
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Business name')),
          TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Your name (for your weekly message)')),
          TextField(controller: _type, decoration: const InputDecoration(labelText: 'What do you sell? (e.g. rice, food, provisions)')),
          const SizedBox(height: 8),
          const Text('Next, add the items you sell on the Items tab.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _start, child: const Padding(padding: EdgeInsets.all(12), child: Text('Start'))),
        ],
      ),
    );
  }
}
