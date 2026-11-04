import 'package:flutter/material.dart';

import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import '../fx/fx_view.dart';
import 'product_screen.dart';

/// "Answer, not dashboard": the first thing an owner reads is what to buy.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, required this.onLog, required this.onBuy, required this.onSettings});
  final ShopRepo repo;
  final VoidCallback onLog, onBuy, onSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _mascot = FxController();
  String _last = '';

  /// Benj's mood is always true to the shop's real state.
  ({String state, String line}) _mood() {
    final r = widget.repo;
    final name = r.shop?.ownerName.split(' ').first ?? '';
    final hi = name.isEmpty ? 'Hello' : 'Hello $name';
    if (r.products.isEmpty) return (state: 'wave', line: '$hi! Add what you sell and I\'ll watch it for you.');
    if (r.daysSinceLastLog >= 2 && r.daysSinceLastLog < 999) return (state: 'sleep', line: 'No logs for ${r.daysSinceLastLog} days. My guesses get worse without them.');
    final w = r.warnings;
    if (w.isNotEmpty) return (state: 'worried', line: '${w.first.$1.label}: ${daysLeftText(w.first.$2).toLowerCase()}.');
    if (r.rows.every((x) => x.$2.learning)) return (state: 'think', line: 'I\'m still learning your shop. Keep logging for a few days.');
    if (!r.loggedToday) return (state: 'log', line: 'Everything looks fine. Log today so I stay sharp.');
    return (state: 'idle', line: 'All good today. Nothing is about to run out.');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.repo;
    final mood = _mood();
    if (mood.state != _last) {
      _last = mood.state;
      _mascot.send({'state': mood.state});
    }
    final answer = homeAnswer(r.rows, r.today);
    final warnings = r.warnings;
    final week = r.lastSevenLogged;
    final logged = week.where((x) => x).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.shop?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: B.display(24)),
              const SizedBox(height: 2),
              _SyncLine(repo: r),
            ]),
          ),
          IconButton(tooltip: 'Settings', onPressed: widget.onSettings, icon: const Icon(Icons.tune_rounded)),
        ]),
        const SizedBox(height: 10),
        // The answer, with Benj beside it.
        Container(
          height: 232,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2250), Color(0xFF0F1330)]),
            border: Border.all(color: B.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(right: -28, top: 4, bottom: -22, width: 176, child: Mascot(state: mood.state, controller: _mascot, turn: -0.25)),
            Positioned(
              left: 18,
              top: 18,
              bottom: 16,
              right: 136,
              child: IgnorePointer(
                ignoring: answer.isEmpty,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(answer.isEmpty ? 'BENJ SAYS' : 'THIS WEEK', style: B.mono(11, color: B.gold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      answer.isEmpty ? mood.line : answer,
                      overflow: TextOverflow.fade,
                      style: B.display(answer.length > 60 ? 20 : 23),
                    ),
                  ),
                  if (answer.isNotEmpty) TextButton(onPressed: widget.onBuy, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 36), foregroundColor: B.gold), child: const Text('See the full list →')),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: widget.onLog, icon: const Icon(Icons.edit_note_rounded), label: Text(r.products.isEmpty ? 'Add what you sell' : (r.loggedToday ? 'Log more' : 'Log today'))),
        const SizedBox(height: 18),
        if (warnings.isNotEmpty) ...[
          Text('Running low', style: B.display(19)),
          const SizedBox(height: 8),
          for (final (p, f) in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                onTap: () => openProduct(context, r, p.id),
                border: B.coral.withValues(alpha: .35),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.label, style: B.body(16, w: FontWeight.w700)),
                      Text('${tidy(f.stock)} ${p.plural(f.stock)} left, warning level ${tidy(f.warningLevel)}', style: B.body(13, color: B.mute)),
                    ]),
                  ),
                  Pill(daysLeftText(f), color: B.urgency(f.daysLeft, true)),
                ]),
              ),
            ),
          const SizedBox(height: 10),
        ],
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Days logged this week', style: B.body(15, w: FontWeight.w700))),
              Text('$logged of 7', style: B.mono(13, color: logged >= 5 ? B.teal : B.gold)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Container(
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: week[i] ? B.teal : B.raised, border: i == 6 ? Border.all(color: B.gold) : null),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text('The more days you log, the better my warnings get.', style: B.body(13, color: B.mute)),
          ]),
        ),
      ],
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.repo});
  final ShopRepo repo;

  @override
  Widget build(BuildContext context) {
    final pending = repo.hasPendingWrites;
    final offline = repo.fromCache;
    final color = pending || offline ? B.gold : B.teal;
    final text = pending ? 'Saved on this phone, will sync' : (offline ? 'Offline, your logs are safe' : 'Synced');
    return Row(children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: B.body(12.5, color: B.mute)),
    ]);
  }
}
