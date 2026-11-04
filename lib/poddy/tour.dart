import 'package:flutter/material.dart';

import 'poddy.dart';

class TourStep {
  const TourStep(this.text, {this.target});
  final String text;

  /// The part of the screen to light up; null means just Poddy talking.
  final GlobalKey? target;
}

/// First-visit orientation: the screen dims, Poddy hovers and lights up one part at a
/// time with a few words. Next / Skip, shown once per account.
class PoddyTour extends StatefulWidget {
  const PoddyTour({super.key, required this.steps, required this.onDone});
  final List<TourStep> steps;
  final VoidCallback onDone;

  @override
  State<PoddyTour> createState() => _PoddyTourState();
}

class _PoddyTourState extends State<PoddyTour> {
  int _i = 0;

  Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: me);
    return (topLeft & box.size).inflate(10);
  }

  void _next() {
    if (_i + 1 >= widget.steps.length) {
      widget.onDone();
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final hole = _rectOf(step.target);
    final size = MediaQuery.of(context).size;
    final scheme = Theme.of(context).colorScheme;
    final last = _i == widget.steps.length - 1;
    // Poddy floats away from whatever is lit up: up top for bottom targets, lower for top ones.
    final poddyTop = hole != null && hole.center.dy < size.height * 0.35 ? hole.bottom + 20 : size.height * 0.16;

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _next,
            child: CustomPaint(painter: _Dim(hole: hole, color: Colors.black.withValues(alpha: 0.62), ring: scheme.primaryContainer)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: poddyTop,
          child: Column(children: [
            const SizedBox(height: 170, width: 170, child: PoddyView(mood: 'present')),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(step.text, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${_i + 1} of ${widget.steps.length}', style: Theme.of(context).textTheme.labelSmall),
                  const Spacer(),
                  if (!last) TextButton(onPressed: widget.onDone, child: const Text('Skip')),
                  FilledButton(onPressed: _next, child: Text(last ? "Let's go" : 'Next')),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Dark veil with a rounded window over the highlighted part.
class _Dim extends CustomPainter {
  _Dim({required this.hole, required this.color, required this.ring});
  final Rect? hole;
  final Color color, ring;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(all, Paint()..color = color);
      return;
    }
    final window = RRect.fromRectAndRadius(hole!, const Radius.circular(16));
    canvas.drawPath(Path.combine(PathOperation.difference, all, Path()..addRRect(window)), Paint()..color = color);
    canvas.drawRRect(window, Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_Dim old) => old.hole != hole;
}
