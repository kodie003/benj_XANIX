import 'package:flutter/widgets.dart';

// Android and iOS builds: effects aren't wired up yet, so FxView shows its fallback.
// The PRD's v1 is the web app; native 3D can later load web/fx/benj.glb with flutter_scene.
const bool supported = false;

class FxHost {
  FxHost(String kind, String config, void Function(String) onEvent);
  void send(String json) {}
  void dispose() {}
  Widget build() => const SizedBox.shrink();
}

bool get voiceSupported => false;
void voiceStart(void Function(String text, bool isFinal) onResult, void Function(String error) onEnd) => onEnd('unsupported');
void voiceStop() {}
