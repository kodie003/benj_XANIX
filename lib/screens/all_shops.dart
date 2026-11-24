import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/branches.dart';
import '../core/forecast.dart';
import '../core/models.dart';
import '../core/repo.dart';
import 'ui.dart';

Future<void> openAllShops(BuildContext context, ShopRepo own, BranchList branches) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AllShopsScreen(own: own, branches: branches)));

/// Stock across the owner's shops. The owner ticks which shops count (their main shop,
/// any branch or warehouse) and sees each product's total, with how much is where.
class AllShopsScreen extends StatefulWidget {
  const AllShopsScreen({super.key, required this.own, required this.branches});
  final ShopRepo own;
  final BranchList branches;

  @override
  State<AllShopsScreen> createState() => _AllShopsScreenState();
}

/// One product line: the same name, size and unit, added up over the ticked shops.
class _Line {
  _Line(this.product);
  final Product product;
  final parts = <(String shop, Forecast f)>[];
  double get total => parts.fold(0, (s, p) => s + p.$2.stock);
  bool get anyLow => parts.any((p) => p.$2.isLow);
}

class _AllShopsScreenState extends State<AllShopsScreen> {
  // Branch shops opened just for this screen; the main shop's repo is the owner's own.
  final _opened = <String, ShopRepo>{};

  /// Ticked shop ids. null until loaded from this phone (default: all of them).
  Set<String>? _ticked;

  String get _prefKey => 'benj_all_shops_${widget.own.uid}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getStringList(_prefKey);
      if (mounted) setState(() => _ticked = saved?.toSet() ?? {for (final s in _shops) s.$1});
    }).catchError((_) {
      if (mounted) setState(() => _ticked = {for (final s in _shops) s.$1});
    });
  }

  ShopRepo _repo(String uid) => uid == widget.own.uid ? widget.own : _opened.putIfAbsent(uid, () => ShopRepo(uid));

  /// Main shop first, then branches A to Z: (uid, name).
  List<(String, String)> get _shops => [
        (widget.own.uid, widget.own.shop?.name ?? 'Main shop'),
        for (final b in widget.branches.branches) (b.uid, b.name),
      ];

  Future<void> _toggle(String uid, bool on) async {
    final next = {...?_ticked};
    on ? next.add(uid) : next.remove(uid);
    setState(() => _ticked = next);
    try {
      (await SharedPreferences.getInstance()).setStringList(_prefKey, next.toList());
    } catch (_) {
      // Only a convenience: the choice still holds on this screen.
    }
  }

  @override
  void dispose() {
    for (final r in _opened.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticked = _ticked;
    final shops = _shops;
    final repos = [for (final (uid, _) in shops) if (ticked?.contains(uid) ?? false) _repo(uid)];
    return ListenableBuilder(
      listenable: Listenable.merge([widget.branches, widget.own, ...repos]),
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final loading = ticked == null || repos.any((r) => !r.shopLoaded);
        final names = {for (final (uid, name) in shops) uid: name};
        final lines = <String, _Line>{};
        for (final r in repos) {
          for (final p in r.products) {
            final f = r.forecasts[p.id];
            if (f == null) continue;
            (lines['${p.key}|${p.unit}'] ??= _Line(p)).parts.add((names[r.uid] ?? r.shop?.name ?? '', f));
          }
        }
        final list = lines.values.toList()
          ..sort((a, b) => a.anyLow != b.anyLow ? (a.anyLow ? -1 : 1) : a.product.label.toLowerCase().compareTo(b.product.label.toLowerCase()));
        final low = list.where((l) => l.anyLow).length;
        return Scaffold(
          appBar: AppBar(title: const Text('Stock across shops')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
            Text('Which shops to count?', style: text.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final (i, (uid, name)) in shops.indexed)
                FilterChip(
                  label: Text(i == 0 ? '$name (main)' : name),
                  selected: ticked?.contains(uid) ?? false,
                  onSelected: ticked == null ? null : (on) => _toggle(uid, on),
                ),
            ]),
            const SizedBox(height: 14),
            if (ticked != null && ticked.isEmpty)
              const Empty(icon: Icons.storefront_outlined, text: 'Tick at least one shop above.')
            else if (loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const Empty(icon: Icons.inventory_2_outlined, text: 'No products in these shops yet.')
            else ...[
              Text(
                '${repos.length} ${repos.length == 1 ? 'shop' : 'shops'} · ${list.length} ${list.length == 1 ? 'product' : 'products'}${low > 0 ? ' · $low running low somewhere' : ''}',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(children: [
                  for (final l in list) _row(context, l, showParts: repos.length > 1),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }

  Widget _row(BuildContext context, _Line l, {required bool showParts}) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(l.anyLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined, color: l.anyLow ? scheme.error : null),
      title: Text(l.product.label),
      subtitle: showParts
          ? Text.rich(TextSpan(children: [
              for (final (i, (shop, f)) in l.parts.indexed) ...[
                if (i > 0) const TextSpan(text: ' · '),
                TextSpan(
                  text: '$shop ${qty(f.stock)}${f.isLow ? ' (low)' : ''}',
                  style: f.isLow ? TextStyle(color: scheme.error, fontWeight: FontWeight.w600) : null,
                ),
              ],
            ]))
          : (l.anyLow ? Text('Running low', style: TextStyle(color: scheme.error)) : null),
      trailing: Text(units(l.product, l.total), style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
