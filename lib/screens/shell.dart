import 'package:flutter/material.dart';

import '../core/repo.dart';
import '../core/theme.dart';
import '../widgets/sparkle.dart';
import 'buying_screen.dart';
import 'home_screen.dart';
import 'log_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';

/// Home answers "what do I do?", Log feeds it, Buy is the list, Stock shows the proof.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.repo});
  final ShopRepo repo;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  void go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Stack(children: [
              // Effects only run on the tab being looked at, which keeps cheap phones cool.
              switch (_tab) {
                0 => HomeScreen(key: const ValueKey('home'), repo: repo, onLog: () => go(1), onBuy: () => go(2), onSettings: () => openSettings(context, repo)),
                1 => LogScreen(key: const ValueKey('log'), repo: repo, onDone: () => go(0)),
                2 => BuyingScreen(key: const ValueKey('buy'), repo: repo),
                _ => StockScreen(key: const ValueKey('stock'), repo: repo),
              },
              SparkleCompanion(repo: repo, onLog: () => go(1), onBuy: () => go(2), onStock: () => go(3)),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: B.surface,
        indicatorColor: B.gold.withValues(alpha: .22),
        selectedIndex: _tab,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: go,
        destinations: [
          NavigationDestination(icon: Badge(isLabelVisible: repo.warnings.isNotEmpty, backgroundColor: B.coral, label: Text('${repo.warnings.length}'), child: const Icon(Icons.home_outlined)), selectedIcon: const Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.edit_note_rounded), label: 'Log'),
          const NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), selectedIcon: Icon(Icons.shopping_basket_rounded), label: 'Buy'),
          const NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Stock'),
        ],
      ),
    );
  }
}
