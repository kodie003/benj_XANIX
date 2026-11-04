import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';

/// Draws Poddy (web/poddy/poddy.js) inside a platform view.
class PoddyView extends StatefulWidget {
  const PoddyView({super.key, required this.mood, this.flash, this.flashTick = 0});

  /// Resting mood: idle, hello, present, shock, sad, sleep.
  final String mood;

  /// A short reaction played once each time [flashTick] changes, e.g. "welcome".
  final String? flash;
  final int flashTick;

  @override
  State<PoddyView> createState() => _PoddyViewState();
}

class _PoddyViewState extends State<PoddyView> {
  JSObject? _el;

  JSObject? get _api => globalContext['Poddy'] as JSObject?;

  /// False only when we know WebGL is missing; the script may still be loading.
  bool get _supported {
    final api = _api;
    return api == null || (api.callMethod<JSBoolean>('supported'.toJS)).toDart;
  }

  Future<void> _mountWhenReady() async {
    for (var i = 0; i < 100 && _api == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final el = _el, api = _api;
    if (!mounted || el == null || api == null) return;
    api.callMethod('mount'.toJS, el, widget.mood.toJS);
  }

  @override
  void didUpdateWidget(PoddyView old) {
    super.didUpdateWidget(old);
    final el = _el, api = _api;
    if (el == null || api == null) return;
    if (old.mood != widget.mood) api.callMethod('set'.toJS, el, widget.mood.toJS);
    if (widget.flash != null && old.flashTick != widget.flashTick) {
      api.callMethod('set'.toJS, el, widget.flash!.toJS, 2600.toJS);
    }
  }

  @override
  void dispose() {
    final el = _el, api = _api;
    if (el != null && api != null) api.callMethod('dispose'.toJS, el);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Old phones without WebGL simply don't get a mascot; nothing else depends on him.
    if (!_supported) return const SizedBox.shrink();
    return Semantics(
      label: 'Poddy, the SeeYou helper',
      child: HtmlElementView.fromTagName(
        tagName: 'div',
        onElementCreated: (Object el) {
          _el = el as JSObject;
          _mountWhenReady();
        },
      ),
    );
  }
}
