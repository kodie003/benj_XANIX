import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import '../fx/fx_view.dart';
import 'capture_sheets.dart';
import 'product_form.dart';

/// F2 and F3. One screen, big targets, done in seconds. The Munchies manager gets
/// interrupted constantly, so a half-finished log survives switching tabs.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.repo, required this.onDone});
  final ShopRepo repo;
  final VoidCallback onDone;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _Draft {
  String mode = 'sale';
  final qty = <String, double>{};
  final price = <String, double>{};
  DateTime? startedAt;
  void clear() {
    qty.clear();
    price.clear();
    startedAt = null;
  }
}

class _LogScreenState extends State<LogScreen> {
  static final _draft = _Draft();
  static const _modes = {'sale': 'Sold', 'count': 'Counted', 'restock': 'Bought'};

  ShopRepo get r => widget.repo;

  void _touch() => _draft.startedAt ??= DateTime.now();

  void _bump(String id, double by) {
    HapticFeedback.selectionClick();
    _touch();
    setState(() {
      final v = (_draft.qty[id] ?? 0) + by;
      if (v <= 0) {
        _draft.qty.remove(id);
      } else {
        _draft.qty[id] = v;
      }
    });
  }

  Future<void> _save() async {
    final entries = _draft.qty.entries.where((e) => e.value > 0 || _draft.mode == 'count').toList();
    if (entries.isEmpty) return;
    final seconds = _draft.startedAt == null ? null : DateTime.now().difference(_draft.startedAt!).inSeconds;
    final now = DateTime.now();
    // Time goes on the session's first entry only, so the median is per session.
    final list = [
      for (final (i, e) in entries.indexed)
        StockLog(
          product: e.key,
          at: now,
          type: _draft.mode,
          quantity: e.value,
          unitPrice: _draft.mode == 'restock' ? _draft.price[e.key] : null,
          method: 'tap',
          secondsTaken: i == 0 ? seconds : null,
        ),
    ];
    await saveWithGlow(context, r.addLogs(list), 'Saved. ${list.length} ${list.length == 1 ? 'item' : 'items'} logged.');
    _draft.clear();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _draft.mode;
    final dirty = _draft.qty.isNotEmpty;
    return Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: LedgerPainter())),
      ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 170),
        children: [
          Row(children: [
            Expanded(child: Text('Log', style: B.display(28))),
            _RoundAction(icon: Icons.mic_rounded, label: 'Speak', color: B.teal, onTap: r.products.isEmpty ? null : () => openVoice(context, r)),
            const SizedBox(width: 8),
            _RoundAction(icon: Icons.photo_camera_rounded, label: 'Photo', color: B.violet, onTap: r.products.isEmpty ? null : () => openPhoto(context, r)),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
              textStyle: WidgetStatePropertyAll(B.body(15, w: FontWeight.w700)),
              backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? B.gold : B.surface),
              foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF241600) : B.text),
            ),
            segments: [for (final e in _modes.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {mode},
            onSelectionChanged: (s) => setState(() {
              _draft.mode = s.first;
              _draft.qty.clear();
              _draft.price.clear();
            }),
          ),
          const SizedBox(height: 6),
          Text(
            {'sale': 'Tap + for each one sold today.', 'count': 'Type what is on the shelf right now.', 'restock': 'What did you bring back from the market?'}[mode]!,
            style: B.body(14, color: B.mute),
          ),
          const SizedBox(height: 10),
          if (r.products.isEmpty)
            Panel(
              child: Column(children: [
                const SizedBox(height: 180, child: Mascot(state: 'point')),
                Text('Start with your top sellers', style: B.display(21)),
                const SizedBox(height: 6),
                Text('Add 10 to 20 products. Bags, packs, cartons, crates: anything you can count.', textAlign: TextAlign.center, style: B.body(14, color: B.mute)),
              ]),
            ),
          for (final p in r.products) _row(p, mode),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => openProductForm(context, r), icon: const Icon(Icons.add_rounded), label: const Text('Add a product')),
        ],
      ),
      if (dirty)
        Positioned(
          left: 18,
          right: 18,
          bottom: 16,
          child: FilledButton(onPressed: _save, child: Text('Save ${_draft.qty.length} ${_draft.qty.length == 1 ? 'item' : 'items'}')),
        ),
    ]);
  }

  Widget _row(Product p, String mode) {
    final f = r.forecasts[p.id];
    final stock = f?.stock ?? 0;
    final q = _draft.qty[p.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        border: q != null ? B.gold.withValues(alpha: .55) : null,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.label, style: B.body(16, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: B.urgency(f?.daysLeft, f?.isLow ?? false))),
                const SizedBox(width: 6),
                Flexible(child: Text('${tidy(stock)} ${p.plural(stock)} on hand', overflow: TextOverflow.ellipsis, style: B.body(13, color: B.mute))),
              ]),
              if (mode == 'restock' && q != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: 150,
                  height: 42,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: B.body(14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      prefixText: 'GH₵ ',
                      hintText: p.costPrice == null ? 'price each' : tidy(p.costPrice!).toString(),
                    ),
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n == null) {
                        _draft.price.remove(p.id);
                      } else {
                        _draft.price[p.id] = n;
                      }
                    },
                  ),
                ),
              ],
            ]),
          ),
          if (mode == 'count')
            SizedBox(
              width: 92,
              child: TextField(
                key: ValueKey('c${p.id}'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: B.display(22),
                decoration: const InputDecoration(hintText: '–', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                onChanged: (v) {
                  _touch();
                  setState(() {
                    final n = double.tryParse(v);
                    if (n == null) {
                      _draft.qty.remove(p.id);
                    } else {
                      _draft.qty[p.id] = n;
                    }
                  });
                },
              ),
            )
          else ...[
            _Step(icon: Icons.remove_rounded, label: 'One less ${p.label}', onTap: q == null ? null : () => _bump(p.id, -1)),
            SizedBox(width: 44, child: Text(q == null ? '0' : '${tidy(q)}', textAlign: TextAlign.center, style: B.display(22, color: q == null ? B.mute : B.gold))),
            _Step(icon: Icons.add_rounded, label: 'One more ${p.label}', primary: true, onTap: () => _bump(p.id, 1)),
          ],
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 50,
        child: Material(
          color: primary ? B.gold : B.raised,
          borderRadius: BorderRadius.circular(14),
          child: Semantics(
            label: label,
            button: true,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Icon(icon, color: primary ? const Color(0xFF241600) : (onTap == null ? B.mute.withValues(alpha: .4) : B.text), size: 26),
            ),
          ),
        ),
      );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.color, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: B.body(14, w: FontWeight.w700, color: color)),
            ]),
          ),
        ),
      );
}

/// Shown once a log is confirmed, whichever way it was entered: the glow breathes while
/// it saves, resolves into a tick, and Benj celebrates.
Future<void> saveWithGlow(BuildContext context, Future<void> work, String doneText) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xF2060814),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => _SavingOverlay(work: work, doneText: doneText),
  );
}

class _SavingOverlay extends StatefulWidget {
  const _SavingOverlay({required this.work, required this.doneText});
  final Future<void> work;
  final String doneText;

  @override
  State<_SavingOverlay> createState() => _SavingOverlayState();
}

class _SavingOverlayState extends State<_SavingOverlay> {
  final _glow = FxController();
  final _mascot = FxController();
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final minShow = Future.delayed(const Duration(milliseconds: 1100));
    try {
      await widget.work;
    } catch (e) {
      _error = 'That didn\'t save. Check your entries and try again.';
    }
    await minShow;
    if (!mounted) return;
    setState(() => _done = true);
    _glow.send({'done': _error == null});
    if (_error == null) _mascot.send({'state': 'celebrate', 'ms': 1500});
    await Future.delayed(Duration(milliseconds: _error == null ? 1500 : 2400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 300,
            height: 260,
            child: Stack(children: [
              Positioned.fill(child: FxView(kind: 'glow', controller: _glow, fallback: const Center(child: CircularProgressIndicator()))),
            ]),
          ),
          SizedBox(height: 150, width: 150, child: Mascot(state: 'run', controller: _mascot)),
          const SizedBox(height: 10),
          Text(_error ?? (_done ? widget.doneText : 'Saving…'), textAlign: TextAlign.center, style: B.display(21, color: _error != null ? B.coral : B.text)),
        ]),
      );
}
