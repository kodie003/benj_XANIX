import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import '../fx/fx_view.dart';
import '../screens/capture_sheets.dart';

/// The floating sparkle: a small companion that drifts over every screen, can be dragged
/// out of the way, and pulses when something needs attention. Tap it and Benj answers the
/// owner's real questions from their own records, with no sign-up to any AI needed.
/// Drawn by Flutter rather than WebGL, so it stays smooth on cheap phones.
class SparkleCompanion extends StatefulWidget {
  const SparkleCompanion({super.key, required this.repo, required this.onLog, required this.onBuy, required this.onStock});
  final ShopRepo repo;
  final VoidCallback onLog, onBuy, onStock;

  @override
  State<SparkleCompanion> createState() => _SparkleCompanionState();
}

class _SparkleCompanionState extends State<SparkleCompanion> with SingleTickerProviderStateMixin {
  late final _tick = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  Offset? _pos;
  static const _size = 68.0;

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Starts above the save buttons and sliders that live along the bottom edge.
      final pos = _pos ?? Offset(c.maxWidth - _size - 10, c.maxHeight - _size - 96);
      final clamped = Offset(pos.dx.clamp(4, math.max(4, c.maxWidth - _size - 4)), pos.dy.clamp(4, math.max(4, c.maxHeight - _size - 4)));
      return Stack(children: [
        AnimatedBuilder(
          animation: _tick,
          builder: (context, _) {
            final t = _tick.value * math.pi * 2;
            final bob = math.sin(t * 4) * 4;
            return Positioned(
              left: clamped.dx,
              top: clamped.dy + bob,
              child: GestureDetector(
                onTap: () => _open(context),
                onPanUpdate: (d) => setState(() => _pos = clamped + d.delta),
                onPanEnd: (_) {
                  // Snap to the nearest side so it never hides a button.
                  final left = clamped.dx + _size / 2 < c.maxWidth / 2;
                  setState(() => _pos = Offset(left ? 10 : c.maxWidth - _size - 10, clamped.dy));
                },
                child: Semantics(
                  button: true,
                  label: 'Ask Benj',
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: CustomPaint(painter: _SparklePainter(_tick.value, widget.repo.warnings.isNotEmpty)),
                  ),
                ),
              ),
            );
          },
        ),
      ]);
    });
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AskSheet(repo: widget.repo, onLog: widget.onLog, onBuy: widget.onBuy, onStock: widget.onStock),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.v, this.alert);
  final double v;
  final bool alert;

  Path _star(Offset c, double r, double pinch, [double rot = 0]) {
    final p = Path();
    for (var i = 0; i < 4; i++) {
      final a = rot + i * math.pi / 2;
      final tip = c + Offset(math.cos(a), math.sin(a)) * r;
      final next = c + Offset(math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)) * r;
      if (i == 0) p.moveTo(tip.dx, tip.dy);
      final ctrl = c + Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)) * r * pinch;
      p.quadraticBezierTo(ctrl.dx, ctrl.dy, next.dx, next.dy);
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final t = v * math.pi * 2;
    final main = alert ? B.coral : B.gold;
    final breathe = .5 + .5 * math.sin(t * (alert ? 12 : 5));

    // Halo.
    canvas.drawCircle(c, s.width * .46, Paint()..shader = RadialGradient(colors: [main.withValues(alpha: .34 + breathe * .22), main.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: s.width * .46)));
    // Glass bead.
    canvas.drawCircle(
      c,
      s.width * .3,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFF39406F), Color(0xFF121630)]).createShader(Rect.fromCircle(center: c, radius: s.width * .3)),
    );
    canvas.drawCircle(
      c,
      s.width * .3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = SweepGradient(transform: GradientRotation(t * 2), colors: [main, B.teal, B.violet, main]).createShader(Rect.fromCircle(center: c, radius: s.width * .3)),
    );
    // The main star gently twists.
    final r = s.width * (.19 + breathe * .025);
    canvas.drawPath(_star(c, r, .22, math.sin(t * 2) * .22 - math.pi / 2), Paint()..color = const Color(0xFFFFF4D6));
    canvas.drawPath(
      _star(c, r * .62, .22, math.sin(t * 2) * .22 - math.pi / 2),
      Paint()..shader = RadialGradient(colors: [Colors.white, main]).createShader(Rect.fromCircle(center: c, radius: r * .62)),
    );
    // Three tiny stars orbit and twinkle.
    for (var i = 0; i < 3; i++) {
      final a = t * (2 + i) + i * 2.1;
      final rr = s.width * (.37 + .05 * math.sin(t * 3 + i));
      final p = c + Offset(math.cos(a), math.sin(a) * .82) * rr;
      final tw = .5 + .5 * math.sin(t * 13 + i * 2);
      canvas.drawPath(_star(p, 2.0 + tw * 2.6, .2), Paint()..color = Colors.white.withValues(alpha: .35 + tw * .65));
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter o) => o.v != v || o.alert != alert;
}

// ======================= Ask Benj =======================
class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.repo, required this.onLog, required this.onBuy, required this.onStock});
  final ShopRepo repo;
  final VoidCallback onLog, onBuy, onStock;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _mascot = FxController();
  String? _question, _answer;
  VoidCallback? _action;
  String? _actionLabel;

  ShopRepo get r => widget.repo;

  void _ask(String q) {
    late String a;
    VoidCallback? act;
    String? label;
    var mood = 'talk';
    switch (q) {
      case 'What should I buy?':
        final s = homeAnswer(r.rows, r.today);
        a = s.isEmpty ? (r.rows.isNotEmpty && r.rows.every((x) => x.$2.learning) ? 'I need 3 days of logs before I suggest amounts. Keep logging!' : 'Nothing right now. You have enough for the next 7 days.') : '$s.';
        act = widget.onBuy;
        label = 'Open the list';
      case 'What is running out?':
        final w = r.warnings;
        if (w.isEmpty) {
          a = 'Nothing is below its warning level. You\'re fine for now.';
        } else {
          a = w.take(3).map((x) => '${x.$1.label}: ${daysLeftText(x.$2).toLowerCase()}').join('. ');
          a += '${w.length > 3 ? ', and ${w.length - 3} more' : ''}.';
          mood = 'worried';
        }
        act = widget.onStock;
        label = 'See my stock';
      case 'What moves fastest?':
        final rows = [...r.rows]..sort((a, b) => b.$2.meanDaily.compareTo(a.$2.meanDaily));
        final top = rows.where((x) => x.$2.meanDaily > 0).take(3).toList();
        a = top.isEmpty ? 'I haven\'t seen any sales yet. Log a few and I\'ll tell you.' : top.map((x) => '${x.$1.label}: ${x.$2.meanDaily.toStringAsFixed(1)} a day').join('. ');
        a = a.endsWith('.') ? a : '$a.';
      case 'Was I right last week?':
        final errs = <double>[];
        for (final p in r.products) {
          final c = weekChecks(p, r.logsFor(p.id), r.events, r.today);
          if (c.isNotEmpty) errs.add(c.last.error);
        }
        if (errs.isEmpty) {
          a = 'I can\'t say yet. I need a full week of logs to check myself against what really sold.';
        } else {
          errs.sort();
          final m = errs[errs.length ~/ 2];
          a = 'Typically I was ${(m * 100).round()}% off last week. ${m <= .2 ? 'That\'s close enough to act on.' : 'That\'s rough, so double-check me for now.'}';
        }
      default:
        final n = r.lastSevenLogged.where((x) => x).length;
        a = r.loggedToday ? 'You\'ve logged today, and $n of the last 7 days. Nice.' : 'Not yet today. You\'ve logged $n of the last 7 days. It only takes a moment.';
        act = widget.onLog;
        label = 'Log now';
    }
    _mascot.send({'state': mood, 'ms': mood == 'talk' ? 1800 : 2600});
    setState(() {
      _question = q;
      _answer = a;
      _action = act;
      _actionLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 118, height: 150, child: Mascot(state: 'wave', framing: 'bust', controller: _mascot, onTap: () => _mascot.send({'state': 'celebrate', 'ms': 1500}))),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(_answer),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_question?.toUpperCase() ?? 'ASK BENJ', style: B.mono(11, color: B.gold)),
                        const SizedBox(height: 8),
                        Text(_answer ?? 'What do you want to know about your shop?', style: B.display(19, height: 1.18)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
            if (_action != null) ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _action!();
                },
                child: Text(_actionLabel!),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in const ['What should I buy?', 'What is running out?', 'What moves fastest?', 'Was I right last week?', 'Have I logged today?'])
                ActionChip(
                  label: Text(q),
                  labelStyle: B.body(14, w: FontWeight.w600),
                  backgroundColor: q == _question ? B.gold.withValues(alpha: .2) : B.raised,
                  side: const BorderSide(color: B.line),
                  onPressed: () => _ask(q),
                ),
              ActionChip(
                avatar: const Icon(Icons.mic_rounded, size: 18, color: B.teal),
                label: const Text('Speak a log'),
                labelStyle: B.body(14, w: FontWeight.w600),
                backgroundColor: B.raised,
                side: const BorderSide(color: B.line),
                onPressed: r.products.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        openVoice(context, r);
                      },
              ),
            ]),
          ]),
        ),
      );
}
