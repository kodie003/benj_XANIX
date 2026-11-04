/// Speech input is web-only for now (web/voice.js).
class Voice {
  static bool get supported => false;
  static void start(void Function(String text, bool isFinal) onText, void Function(String error) onEnd) => onEnd('unsupported');
  static void stop() {}
}
