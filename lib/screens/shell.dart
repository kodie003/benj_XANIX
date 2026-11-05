import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../brand.dart';
import '../core/repo.dart';
import '../poddy/ask.dart';
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

  /// Steps of a short "Show me" tour Poddy gives after answering a question;
  /// null means the first-visit orientation.
  List<TourStep>? _guide;

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
    if (_guide != null) {
      setState(() {
        _guide = null;
        _touring = false;
      });
      return;
    }
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

  /// Ask Poddy: a typed question; if Poddy says where it's done, go there and show how.
  Future<void> _ask() async {
    final section = await showAskPoddy(context, widget.repo);
    if (section != null && mounted) showSection(section);
  }

  /// Takes the owner to the right place and walks them through it in 2-3 steps.
  void showSection(String section) {
    final settings = TourStep('Tap Settings, the gear at the top right.', target: _settingsKey);
    final (int? tab, String? mode, List<TourStep> steps) = switch (section) {
      'log_sold' => (1, 'sale', [TourStep('This is Log. Sold is picked at the top.', target: _bodyKey), TourStep('Tap + for each one sold today.', target: _bodyKey), TourStep('Then tap Save at the bottom.', target: _bodyKey)]),
      'log_count' => (1, 'count', [TourStep('This is Log, on Count.', target: _bodyKey), TourStep('Type how many are on the shelf now, then Save.', target: _bodyKey)]),
      'log_bought' => (1, 'restock', [TourStep('This is Log, on Bought.', target: _bodyKey), TourStep('Tap + for what you bought and type the price, then Save.', target: _bodyKey)]),
      'add_product' => (1, null, [TourStep('Scroll to the bottom of Log and tap "Add a product".', target: _bodyKey), TourStep('Type it, speak it, or take a photo. Then check and Save.', target: _bodyKey)]),
      'delete_product' => (3, null, [TourStep('On Stock, tap the product you want to remove.', target: _bodyKey), TourStep('Then tap the bin icon at the top right, and Delete.', target: _bodyKey)]),
      'buy' => (2, null, [TourStep('This is your buying list for the week.', target: _bodyKey), TourStep('Bought them? Tap "Record what I bought".', target: _bodyKey)]),
      'budget' => (2, null, [TourStep('Type the cash you have at the top.', target: _bodyKey), TourStep('The most urgent items come first.', target: _bodyKey)]),
      'stock' || 'forecast' => (3, null, [TourStep('Each line is one product over time.', target: _bodyKey), TourStep('Tap a product to see if I was right.', target: _bodyKey)]),
      'home' => (0, null, [TourStep('Home shows what is running low and what to buy.', target: _bodyKey)]),
      'duplicates' => (null, null, [settings, const TourStep('Under Products, tap "Remove duplicates".')]),
      'restock_day' => (null, null, [settings, const TourStep('Under Your shop, pick your usual restock day.')]),
      'calendar' => (null, null, [settings, const TourStep('Under Campus calendar, tap Add for exams or breaks.')]),
      'shop_details' => (null, null, [settings, const TourStep('Tap your shop name to change its details.')]),
      'privacy' => (null, null, [settings, const TourStep('Under Account, tap Privacy.')]),
      'delete_account' => (null, null, [settings, const TourStep('Scroll to the very bottom and tap Delete account.')]),
      'sign_out' => (null, null, [settings, const TourStep('Under Account, tap Sign out.')]),
      _ => (null, null, <TourStep>[]),
    };
    if (steps.isEmpty) return;
    setState(() {
      if (tab != null) {
        if (_tab == 0) _welcomed = true;
        _tab = tab;
      }
      if (mode != null) _logMode = mode;
      _guide = steps;
      _touring = true;
    });
  }

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
      onAsk: _ask,
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
        return Stack(children: [scaffold, Positioned.fill(child: PoddyTour(key: ValueKey(_guide), steps: _guide ?? _tour, onDone: _endTour))]);
      },
    );
  }
}
