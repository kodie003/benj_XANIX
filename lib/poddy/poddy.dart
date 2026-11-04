import 'package:flutter/material.dart';

import '../models.dart';
import 'poddy_stub.dart' if (dart.library.js_interop) 'poddy_web.dart';

export 'poddy_stub.dart' if (dart.library.js_interop) 'poddy_web.dart';

/// Poddy's mood always comes from the owner's real records, never for show.
({String mood, String line}) poddyMood(AppState state) {
  if (state.error != null) return (mood: 'sad', line: "I can't reach my notes right now. Your records are safe on this phone.");
  if (state.items.isEmpty) return (mood: 'hello', line: "Hi! Add the items you sell and I'll keep an eye on them.");
  final actions = List<Map<String, dynamic>>.from(state.insights?['actions'] ?? const []);
  final rules = actions.map((a) => a['rule']).toSet();
  if (rules.contains('R1')) return (mood: 'shock', line: 'Something is running low. Look at number 1.');
  if (rules.contains('R8')) {
    final first = state.movements.where((m) => m.type == 'sale').isEmpty;
    return first
        ? (mood: 'present', line: 'Record what you sold today and I can start helping.')
        : (mood: 'sleep', line: "It's been quiet. Record today's sales and I'll wake up.");
  }
  if (actions.isNotEmpty) return (mood: 'present', line: "Here's what I'd do this week.");
  return (mood: 'idle', line: 'All good. Keep recording each day.');
}

/// Poddy with his speech line, for the top of a screen.
class PoddyCard extends StatelessWidget {
  const PoddyCard({super.key, required this.mood, required this.line, this.flashTick = 0, this.height = 170});

  final String mood;
  final String line;
  final int flashTick;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Row(children: [
          SizedBox(width: height * 0.82, child: PoddyView(mood: mood, flash: 'welcome', flashTick: flashTick)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
              child: Text(line, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Text for the credits dialog. The model's CC BY 4.0 licence requires it.
const poddyCredit = 'Poddy is the 3D model "Poddy M1 - Stylized Floating Robot - Posed" by Exmoor beast '
    '(sketchfab.com/Exmoorbeast), licensed under CC BY 4.0 (creativecommons.org/licenses/by/4.0). '
    'We converted it for the web and resized its textures. 3D drawing by three.js (MIT licence).';
