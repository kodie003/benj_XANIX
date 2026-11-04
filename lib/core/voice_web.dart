import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Bridge to web/voice.js (the browser's speech recogniser).
class Voice {
  static JSObject? get _api => globalContext['BenjVoice'] as JSObject?;

  static bool get supported {
    final api = _api;
    return api != null && api.callMethod<JSBoolean>('supported'.toJS).toDart;
  }

  /// [onText] gets the words so far; [onEnd] gets '' or an error code
  /// ('not-allowed' when the microphone is blocked, 'no-speech', 'unsupported').
  static void start(void Function(String text, bool isFinal) onText, void Function(String error) onEnd) {
    final api = _api;
    if (api == null) {
      onEnd('unsupported');
      return;
    }
    api.callMethod(
      'start'.toJS,
      ((JSString t, JSBoolean f) => onText(t.toDart, f.toDart)).toJS,
      ((JSString e) => onEnd(e.toDart)).toJS,
    );
  }

  static void stop() => _api?.callMethod('stop'.toJS);
}
