import '../models.dart';

export 'peek.dart';
export 'poddy_stub.dart' if (dart.library.js_interop) 'poddy_web.dart';

/// Poddy's mood and one short line, always from the owner's real records.
({String mood, String line}) poddyMood(AppState state) {
  if (state.error != null) return (mood: 'sad', line: "Can't reach my notes.");
  if (state.items.isEmpty) return (mood: 'hello', line: 'Add what you sell!');
  final actions = List<Map<String, dynamic>>.from(state.insights?['actions'] ?? const []);
  final rules = actions.map((a) => a['rule']).toSet();
  if (rules.contains('R1')) return (mood: 'shock', line: "Something's running low!");
  if (rules.contains('R8')) {
    final first = state.movements.where((m) => m.type == 'sale').isEmpty;
    return first ? (mood: 'present', line: "Record today's sales.") : (mood: 'sleep', line: "Record today's sales?");
  }
  if (actions.isNotEmpty) return (mood: 'present', line: "Here's your week.");
  return (mood: 'idle', line: 'All good today!');
}

/// Help Poddy offers on each screen when tapped. Kept to three short tips.
const poddyTips = <String, List<String>>{
  'home': [
    'Your 3 actions for the week are listed here.',
    'Tap "I did this" when you have done one.',
    'Send the weekly message to WhatsApp.',
  ],
  'record': [
    'Type how many you sold today, then Save.',
    'Use "Bought / made" when new stock comes in.',
    'Two minutes every evening is enough.',
  ],
  'items': [
    'Add each item with what you pay and what you charge.',
    'Set when to buy more, so I can warn you.',
    'Add busy or quiet days, like school breaks.',
  ],
  'setup': [
    'Only the business name is needed.',
    'You can add your items next.',
  ],
  'signin': [
    'Have a Gmail account? Use Google.',
    'Or use any email with a password.',
  ],
};

/// Text for the credits dialog. The model's CC BY 4.0 licence requires it.
const poddyCredit = 'Poddy is the 3D model "Poddy M1 - Stylized Floating Robot - Posed" by Exmoor beast '
    '(sketchfab.com/Exmoorbeast), licensed under CC BY 4.0 (creativecommons.org/licenses/by/4.0). '
    'We converted it for the web and resized its textures. 3D drawing by three.js (MIT licence).';
