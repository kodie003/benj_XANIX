import '../core/repo.dart';

export 'peek.dart';
export 'tour.dart';
export 'poddy_stub.dart' if (dart.library.js_interop) 'poddy_web.dart';

/// Poddy's mood and one short line, always from the shop's real records.
({String mood, String line}) poddyMood(ShopRepo repo) {
  if (repo.products.isEmpty) return (mood: 'hello', line: 'Add what you sell!');
  final low = repo.warnings;
  if (low.isNotEmpty) return (mood: 'shock', line: '${low.first.$1.label} is running low!');
  if (!repo.loggedToday) {
    return repo.daysSinceLastLog >= 2 ? (mood: 'sleep', line: "Log today's sales?") : (mood: 'present', line: 'Time to log today.');
  }
  return (mood: 'idle', line: 'All good today!');
}

/// Help Poddy offers on each screen when tapped. Three short tips at most.
const poddyTips = <String, List<String>>{
  'home': [
    'Red cards are items about to run out.',
    'Tap "Log today" once a day, it takes seconds.',
    'Your buying list for the week is below.',
  ],
  'log': [
    'Sold: tap + for each one sold today.',
    'Count: type how many are on the shelf now.',
    'Bought something? Record it on the Buy tab.',
  ],
  'buy': [
    'Type the cash you have to spend.',
    'Most urgent items come first.',
    'After buying, tap I bought at the top.',
  ],
  'stock': [
    'Each line is one product over time.',
    'Switch between week and month.',
    'Tap a product to see if benj was right.',
  ],
  'signin': [
    'New? Create a benj account with your phone number.',
    'Have a Gmail account? Use Google.',
  ],
};

/// Text for the credits dialog. The model's CC BY 4.0 licence requires it.
const poddyCredit = 'Poddy is the 3D model "Poddy M1 - Stylized Floating Robot - Posed" by Exmoor beast '
    '(sketchfab.com/Exmoorbeast), licensed under CC BY 4.0 (creativecommons.org/licenses/by/4.0). '
    'We converted it for the web and resized its textures. 3D drawing by three.js (MIT licence).';
