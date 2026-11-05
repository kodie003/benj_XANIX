import 'dart:async';

import 'package:flutter/material.dart';

import 'poddy.dart';

enum PeekSide { left, right, bottom }

/// Poddy peeking in from the edge of the screen with one short line.
///
/// He leans in, says [lines] one after another (a few words each), then ducks back
/// so only his head shows. Tapping him asks "Need help?" and offers [tips].
/// Put it last in a [Stack] that fills the screen body.
class PoddyPeek extends StatefulWidget {
  const PoddyPeek({
    super.key,
    required this.side,
    required this.mood,
    required this.lines,
    this.tips = const [],
    this.flashTick = 0,
    this.flashLine,
    this.lift = 96,
    this.onAsk,
  });

  /// Opens "Ask Poddy" (typed questions answered by Gemini). Null hides the button.
  final VoidCallback? onAsk;

  final PeekSide side;
  final String mood;

  /// Short lines said in turn when Poddy appears or when they change.
  final List<String> lines;

  /// Shown in a sheet when the owner asks for help.
  final List<String> tips;

  /// Each change makes him cheer and say [flashLine].
  final int flashTick;
  final String? flashLine;

  /// Distance from the bottom of the body, for left and right peeks.
  final double lift;

  @override
  State<PoddyPeek> createState() => _PoddyPeekState();
}

class _PoddyPeekState extends State<PoddyPeek> {
  static const _w = 136.0, _h = 176.0;
  bool _out = false;
  String? _line;
  bool _asking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Let the screen settle before he pops in.
    _timer = Timer(const Duration(milliseconds: 700), () => _say(widget.lines));
  }

  @override
  void didUpdateWidget(PoddyPeek old) {
    super.didUpdateWidget(old);
    if (old.flashTick != widget.flashTick && widget.flashLine != null) {
      _say([widget.flashLine!]);
    } else if (old.lines.join('|') != widget.lines.join('|') || old.side != widget.side) {
      _say(widget.lines);
    }
  }

  void _say(List<String> lines, {int i = 0}) {
    _timer?.cancel();
    if (!mounted) return;
    if (i >= lines.length) {
      setState(() {
        _out = false;
        _line = null;
        _asking = false;
      });
      return;
    }
    setState(() {
      _out = true;
      _asking = false;
      _line = lines[i];
    });
    // Long enough to read a few words, short enough not to nag.
    _timer = Timer(Duration(milliseconds: 2200 + 60 * lines[i].length), () => _say(lines, i: i + 1));
  }

  /// Closes "Need something?". Any tap outside its buttons lands here.
  void _dismiss() {
    if (_asking) _say(const []);
  }

  void _tapped() {
    _timer?.cancel();
    if (_asking) {
      _say(const []);
      return;
    }
    setState(() {
      _out = true;
      _asking = true;
      _line = 'Need something?';
    });
    _timer = Timer(const Duration(seconds: 7), () => _say(const []));
  }

  void _showTips() {
    _say(const []);
    if (widget.tips.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      // A tap anywhere closes the tips, on the sheet as well as around it.
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(ctx),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SheetHandle(),
              Text('Quick tips', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final t in widget.tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_outline, size: 20, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: Theme.of(ctx).textTheme.bodyLarge)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // How much of him is visible: leaning in, or just his head at the edge.
    // Tucked away, his whole face still shows so owners know he's there to tap.
    final shown = _out ? 0.8 : 0.6;
    const dur = Duration(milliseconds: 520);
    const curve = Curves.easeOutBack;
    final poddy = SizedBox(width: _w, height: _h, child: PoddyView(mood: widget.mood, flash: 'welcome', flashTick: widget.flashTick, onTap: _tapped));

    // While "Need something?" is open, a tap on the screen closes it and does nothing else.
    final barrier = Positioned.fill(
      child: Semantics(label: 'Close Poddy help', button: true, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _dismiss)),
    );

    Widget body;
    switch (widget.side) {
      case PeekSide.right:
        body = Stack(children: [
          if (_asking) barrier,
          AnimatedPositioned(
            duration: dur,
            curve: curve,
            right: -_w * (1 - shown),
            bottom: widget.lift,
            child: Transform.rotate(angle: -0.18, child: poddy),
          ),
          _bubble(right: _w * shown + 4, bottom: widget.lift + _h * 0.55, alignRight: true),
        ]);
      case PeekSide.left:
        body = Stack(children: [
          if (_asking) barrier,
          AnimatedPositioned(
            duration: dur,
            curve: curve,
            left: -_w * (1 - shown),
            bottom: widget.lift,
            child: Transform.rotate(angle: 0.18, child: poddy),
          ),
          _bubble(left: _w * shown + 4, bottom: widget.lift + _h * 0.55),
        ]);
      case PeekSide.bottom:
        body = Stack(children: [
          if (_asking) barrier,
          AnimatedPositioned(
            duration: dur,
            curve: curve,
            right: 28,
            bottom: -_h * (1 - shown),
            child: poddy,
          ),
          _bubble(right: 28 + _w * 0.75, bottom: _h * shown * 0.7, alignRight: true),
        ]);
    }
    // Normally only Poddy and his bubble take taps, so the screen stays usable. The
    // TapRegion also closes help when the tap is outside this area, like the bottom bar.
    return Positioned.fill(child: TapRegion(onTapOutside: (_) => _dismiss(), child: ClipRect(child: body)));
  }

  Widget _bubble({double? left, double? right, required double bottom, bool alignRight = false}) {
    final scheme = Theme.of(context).colorScheme;
    final line = _line;
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, alignment: alignRight ? Alignment.bottomRight : Alignment.bottomLeft, child: c)),
        child: line == null
            ? const SizedBox.shrink()
            : ConstrainedBox(
                key: ValueKey(line),
                constraints: const BoxConstraints(maxWidth: 200),
                child: GestureDetector(
                  onTap: _asking ? _dismiss : null,
                  child: Material(
                  color: scheme.surface,
                  elevation: 3,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(alignRight ? 16 : 4),
                    bottomRight: Radius.circular(alignRight ? 4 : 16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(line, style: Theme.of(context).textTheme.titleSmall),
                      if (_asking)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(spacing: 6, children: [
                            if (widget.onAsk != null)
                              FilledButton(
                                onPressed: () {
                                  _say(const []);
                                  widget.onAsk!();
                                },
                                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Ask Poddy'),
                              ),
                            if (widget.tips.isNotEmpty)
                              FilledButton.tonal(
                                onPressed: _showTips,
                                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Tips'),
                              ),
                          ]),
                        ),
                    ]),
                  ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The small bar at the top of a sheet. It's drawn inside the sheet's content so a tap
/// on it closes the sheet like a tap anywhere else (Flutter's built-in one doesn't).
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 32,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
        ),
      );
}
