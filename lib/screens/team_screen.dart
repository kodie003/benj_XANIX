import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../fx/fx_view.dart';

/// Dot portraits in the spirit of lusion.co/about. To add a headshot, drop a clear,
/// well-lit square photo at web/team/{id}.jpg; the dots pick it up on their own.
const kTeam = [
  (id: 'selikem', name: 'Selikem Avle', role: 'TEAM LEAD · MIS'),
  (id: 'josephine', name: 'Josephine Yeboah-Kodie', role: 'COMPUTER ENGINEERING'),
  (id: 'moyinoluwa', name: 'Moyinoluwa Afolabi', role: 'MECHATRONICS'),
  (id: 'bright', name: 'Bright Boateng', role: 'BUSINESS ADMINISTRATION'),
  (id: 'emmanuella', name: 'Emmanuella Afefa Bamezon', role: 'BIOENGINEERING'),
];

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _fx = FxController();
  int _index = 0;

  void _go(int i) => _fx.send({'index': i});

  @override
  Widget build(BuildContext context) {
    final m = kTeam[_index];
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFF03050C),
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: h,
          child: Stack(children: [
            Positioned.fill(
              child: FxView(
                kind: 'team',
                controller: _fx,
                config: {
                  'members': [for (final t in kTeam) {'id': t.id, 'name': t.name, 'photo': 'team/${t.id}.jpg'}],
                  'autoMs': 7000,
                },
                onEvent: (e) {
                  if (e['name'] == 'member') setState(() => _index = e['index']);
                },
                fallback: const SizedBox.shrink(),
              ),
            ),
            // Measuring marks and crosses: the instrument-panel framing around the portrait.
            const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Marks()))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 18, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                    const Spacer(),
                    Text('[[   ${(_index + 1).toString().padLeft(3, '0')}   ]]', style: B.mono(12, color: B.text)),
                  ]),
                  Align(alignment: Alignment.centerRight, child: Text('T E A M', style: B.display(44, w: FontWeight.w300, color: B.text))),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Column(
                          key: ValueKey(_index),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('::', style: B.mono(15, color: B.gold)),
                              const SizedBox(width: 8),
                              Flexible(child: Text(m.name, style: B.display(23))),
                            ]),
                            const SizedBox(height: 4),
                            Text(m.role, style: B.mono(11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        for (var i = 0; i < kTeam.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _go(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                                child: Container(height: 2.5, color: i == _index ? B.gold : B.mute.withValues(alpha: .35)),
                              ),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Small shops are not short of records. They are short of foresight.', style: B.display(28)),
            const SizedBox(height: 10),
            Text('We started in Berekuso, sitting with shop owners over handwritten stock books. benj turns those records into one plain answer: what to buy, how much, and when, before you run out.', style: B.body(16, color: B.mute)),
          ]),
        ),
        const SizedBox(height: 380, child: FxView(kind: 'globe', config: {'label': 'Berekuso, Ghana'}, fallback: SizedBox.shrink())),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Text('Team benj · XANIX Challenge 2026 · The Business That Can\'t See Itself', textAlign: TextAlign.center, style: B.mono(10.5)),
        ),
      ]),
    );
  }
}

class _Marks extends CustomPainter {
  const _Marks();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = 1;
    final y = s.height * 0.5;
    for (final f in const [0.06, 0.5, 0.94]) {
      final x = s.width * f;
      c.drawLine(Offset(x - 7, y), Offset(x + 7, y), p);
      c.drawLine(Offset(x, y - 7), Offset(x, y + 7), p);
    }
    final t = s.height * 0.16;
    for (var i = 0; i <= 16; i++) {
      final x = s.width * 0.24 + i * s.width * 0.5 / 16;
      c.drawLine(Offset(x, t), Offset(x, t + (i % 8 == 0 ? 12 : 5)), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}
