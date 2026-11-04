import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../core/repo.dart';
import '../poddy/poddy.dart';
import 'buy.dart';
import 'home.dart';
import 'log.dart';
import 'settings.dart';
import 'stock.dart';

/// The whole product is one loop (PRD section 8): log quickly, get told what to buy,
/// restock, and let the result sharpen the next forecast.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.repo, required this.auth});
  final ShopRepo repo;
  final AuthService auth;

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _tab = 0;
  String _logMode = 'sale';
  bool _welcomed = false;
  bool _touring = false;

  // What the orientation tour lights up.
  final _bodyKey = GlobalKey(), _logKey = GlobalKey(), _buyKey = GlobalKey(), _stockKey = GlobalKey(), _settingsKey = GlobalKey();

  String get _tourFlag => 'benj_tour_done_${widget.repo.uid}';

  @override
  void initState() {
    super.initState();
    // First visit on this account: Poddy shows the owner around once.
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && prefs.getBool(_tourFlag) != true) setState(() => _touring = true);
    });
  }

  Future<void> _endTour() async {
    setState(() {
      _touring = false;
      _welcomed = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourFlag, true);
  }

  List<TourStep> get _tour => [
        const TourStep("Hi! I'm Poddy. Let me show you around."),
        TourStep('Home shows what is running low and what to buy.', target: _bodyKey),
        TourStep('Log: tap what you sold each day. It takes seconds.', target: _logKey),
        TourStep('Buy: your buying list for the week.', target: _buyKey),
        TourStep('Stock: your stock over time, and if I was right.', target: _stockKey),
        TourStep('Settings: your restock day and campus events.', target: _settingsKey),
        const TourStep('Start by adding what you sell. Tap me anytime for help!'),
      ];

  /// Other screens use this to jump to a tab, e.g. "Log today" or "Record what I bought".
  void go(int tab, {String? logMode}) => setState(() {
        if (_tab == 0) _welcomed = true;
        if (logMode != null) _logMode = logMode;
        _tab = tab;
      });

  Widget _peek(ShopRepo repo) {
    final mood = poddyMood(repo);
    final owner = repo.shop?.ownerName.trim() ?? '';
    final (side, lines, tips, pose) = switch (_tab) {
      0 => (PeekSide.right, [if (!_welcomed) owner.isEmpty ? 'Welcome back!' : 'Welcome back, $owner!', mood.line], poddyTips['home']!, mood.mood),
      1 => (PeekSide.left, [repo.products.isEmpty ? 'Add a product first.' : 'Tap what you sold.'], poddyTips['log']!, 'present'),
      2 => (PeekSide.bottom, [repo.products.isEmpty ? 'Nothing to buy yet.' : "Here's your list."], poddyTips['buy']!, 'present'),
      _ => (PeekSide.right, ['Your stock over time.'], poddyTips['stock']!, 'idle'),
    };
    return PoddyPeek(
      key: ValueKey('peek$_tab'),
      side: side,
      mood: pose,
      lines: lines,
      tips: tips,
      flashTick: repo.savedTick,
      flashLine: 'Saved. Nice work!',
      lift: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final pages = [
          HomeScreen(repo: repo, shell: this),
          LogScreen(key: ValueKey(_logMode), repo: repo, initialMode: _logMode),
          BuyScreen(repo: repo, shell: this),
          StockScreen(repo: repo),
        ];
        final scaffold = Scaffold(
          appBar: AppBar(
            title: const BenjLogo(height: 26),
            actions: [
              IconButton(
                key: _settingsKey,
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(repo: repo, auth: widget.auth))),
              ),
            ],
          ),
          body: Stack(children: [KeyedSubtree(key: _bodyKey, child: pages[_tab]), if (!_touring) _peek(repo)]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => go(i),
            destinations: [
              NavigationDestination(
                icon: Badge(isLabelVisible: repo.warnings.isNotEmpty, label: Text('${repo.warnings.length}'), child: const Icon(Icons.home_outlined)),
                label: 'Home',
              ),
              NavigationDestination(icon: Icon(Icons.edit_note, key: _logKey), label: 'Log'),
              NavigationDestination(icon: Icon(Icons.shopping_basket_outlined, key: _buyKey), label: 'Buy'),
              NavigationDestination(icon: Icon(Icons.show_chart, key: _stockKey), label: 'Stock'),
            ],
          ),
        );
        if (!_touring) return scaffold;
        return Stack(children: [scaffold, Positioned.fill(child: PoddyTour(steps: _tour, onDone: _endTour))]);
      },
    );
  }
}
