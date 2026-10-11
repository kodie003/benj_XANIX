import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/home.dart';
import 'screens/items.dart';
import 'screens/record.dart';
import 'screens/setup.dart';

void main() {
  final state = AppState()..load();
  runApp(SeeYouApp(state: state));
}

class SeeYouApp extends StatelessWidget {
  const SeeYouApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeeYou',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B7F4B)),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.isSetUp ? Shell(state: state) : SetupScreen(state: state),
      ),
    );
  }
}

/// Three tabs - the whole product loop: record -> see actions -> act.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pages = [HomeScreen(state: state), RecordScreen(state: state), ItemsScreen(state: state)];
    return Scaffold(
      appBar: AppBar(
        title: const Text('SeeYou'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Update my actions', onPressed: state.refresh),
          PopupMenuButton<String>(
            onSelected: (_) => state.reset(),
            itemBuilder: (_) => [const PopupMenuItem(value: 'reset', child: Text('Start over (deletes records)'))],
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.lightbulb_outline), label: 'This week'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Record'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Items'),
        ],
      ),
    );
  }
}
