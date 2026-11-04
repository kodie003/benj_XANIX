import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('BenjFX')
external _BenjFX? get _fx;

extension type _BenjFX(JSObject _) implements JSObject {
  external JSPromise<JSAny?> mount(web.HTMLElement el, String kind, String json);
  external void send(web.HTMLElement el, String json);
  external void dispose(web.HTMLElement el);
}

const bool supported = true;
int _seq = 0;

class FxHost {
  FxHost(String kind, String config, this._onEvent) : _viewType = 'benj-fx-${_seq++}' {
    _el = web.document.createElement('div') as web.HTMLDivElement;
    _el.style
      ..position = 'relative'
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden';
    _el.addEventListener('fx', ((web.CustomEvent e) => _onEvent((e.detail as JSString).toDart)).toJS);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _el);
    _mount(kind, config);
  }

  final String _viewType;
  final void Function(String) _onEvent;
  late final web.HTMLDivElement _el;
  final _pending = <String>[];
  bool _mounted = false, _dead = false;

  // The effects script is a module and can land just after Flutter does.
  Future<void> _mount(String kind, String config, [int tries = 0]) async {
    if (_dead) return;
    final fx = _fx;
    if (fx == null) {
      if (tries < 100) Timer(const Duration(milliseconds: 100), () => _mount(kind, config, tries + 1));
      return;
    }
    await fx.mount(_el, kind, config).toDart;
    _mounted = true;
    if (_dead) {
      fx.dispose(_el);
      return;
    }
    for (final j in _pending) {
      fx.send(_el, j);
    }
    _pending.clear();
  }

  void send(String json) {
    if (_mounted) {
      _fx?.send(_el, json);
    } else {
      _pending.add(json);
    }
  }

  void dispose() {
    _dead = true;
    _fx?.dispose(_el);
  }

  Widget build() => HtmlElementView(viewType: _viewType);
}

// ---- Voice ----
@JS('BenjVoice')
external _BenjVoice? get _voice;

extension type _BenjVoice(JSObject _) implements JSObject {
  external bool supported();
  external void start(JSFunction onResult, JSFunction onEnd, String lang);
  external void stop();
}

bool get voiceSupported => _voice?.supported() ?? false;

void voiceStart(void Function(String text, bool isFinal) onResult, void Function(String error) onEnd) {
  _voice?.start(
    ((JSString t, JSBoolean f) => onResult(t.toDart, f.toDart)).toJS,
    ((JSString e) => onEnd(e.toDart)).toJS,
    'en-GH',
  );
}

void voiceStop() => _voice?.stop();
