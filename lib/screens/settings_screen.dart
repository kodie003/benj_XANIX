import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../core/forecast.dart';
import '../core/models.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import 'setup_screen.dart' show kDays;
import 'team_screen.dart';

Future<void> openSettings(BuildContext context, ShopRepo repo) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Settings(repo: repo)));

class _Settings extends StatelessWidget {
  const _Settings({required this.repo});
  final ShopRepo repo;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final s = repo.shop;
          Widget tile(IconData i, String t, String sub, VoidCallback tap, {Color? color}) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(i, color: color ?? B.gold),
                title: Text(t, style: B.body(16, w: FontWeight.w700, color: color ?? B.text)),
                subtitle: sub.isEmpty ? null : Text(sub, style: B.body(13, color: B.mute)),
                onTap: tap,
              );
          return Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 30), children: [
                  tile(Icons.storefront_rounded, s?.name ?? 'My shop', [if (s?.location.isNotEmpty ?? false) s!.location, if (s?.ownerPhone.isNotEmpty ?? false) s!.ownerPhone].join(' · '), () => _editShop(context, repo)),
                  tile(Icons.local_shipping_rounded, 'Market day', s?.restockDay == null ? 'Not set' : kDays[s!.restockDay! - 1], () => _editShop(context, repo)),
                  tile(Icons.event_rounded, 'Calendar', '${repo.events.length} ${repo.events.length == 1 ? 'event' : 'events'} shaping your forecast', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalendarScreen(repo: repo)))),
                  tile(Icons.insights_rounded, 'My numbers', 'Days logged, seconds per log, forecast error', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Evidence(repo: repo)))),
                  tile(Icons.groups_rounded, 'The team behind benj', '', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeamScreen()))),
                  const Divider(color: B.line, height: 28),
                  tile(Icons.logout_rounded, 'Sign out', '', () async {
                    Navigator.of(context).pop();
                    await AuthService().signOut();
                  }, color: B.coral),
                ]),
              ),
            ),
          );
        },
      );
}

Future<void> _editShop(BuildContext context, ShopRepo repo) {
  final s = repo.shop!;
  final name = TextEditingController(text: s.name), loc = TextEditingController(text: s.location), phone = TextEditingController(text: s.ownerPhone), owner = TextEditingController(text: s.ownerName);
  var day = s.restockDay;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 18),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your shop', style: B.display(23)),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Shop name')),
            const SizedBox(height: 8),
            TextField(controller: owner, decoration: const InputDecoration(labelText: 'Your name')),
            const SizedBox(height: 8),
            TextField(controller: loc, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 8),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            Text('Market day', style: B.body(14, w: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < 7; i++)
                ChoiceChip(
                  label: Text(kDays[i].substring(0, 3)),
                  selected: day == i + 1,
                  selectedColor: B.gold,
                  labelStyle: B.body(14, w: FontWeight.w700, color: day == i + 1 ? const Color(0xFF241600) : B.text),
                  onSelected: (_) => set(() => day = i + 1),
                ),
            ]),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                repo.saveShop(Shop(name: name.text.trim(), location: loc.text.trim(), ownerPhone: phone.text.trim(), ownerName: owner.text.trim(), restockDay: day, consentAt: s.consentAt));
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ======================= Calendar (F6) =======================
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.repo});
  final ShopRepo repo;

  /// F6: official dates live in assets/ashesi_calendar.json, once the team has them.
  /// Format: [{"name": "Mid-semester break", "start": "2027-03-01", "end": "2027-03-07", "factor": 0.6}]
  Future<List<ShopEvent>> _ashesiDates() async {
    final list = jsonDecode(await rootBundle.loadString('assets/ashesi_calendar.json')) as List;
    return [for (final e in list) ShopEvent(name: e['name'], start: DateTime.parse(e['start']), end: DateTime.parse(e['end']), factor: (e['factor'] as num).toDouble())];
  }

  String _effect(double f) => f == 1 ? 'no change' : (f < 1 ? '${((1 - f) * 100).round()}% fewer customers' : '${((f - 1) * 100).round()}% more customers');

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Calendar')),
          floatingActionButton: FloatingActionButton.extended(backgroundColor: B.gold, foregroundColor: const Color(0xFF241600), onPressed: () => _add(context), icon: const Icon(Icons.add_rounded), label: const Text('Add event')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 100), children: [
                Text('Exams, breaks, orientation, events: whatever changes who walks in. I adjust your list by how much you expect it to change, and show you the adjustment.', style: B.body(14.5, color: B.mute)),
                const SizedBox(height: 14),
                FutureBuilder<List<ShopEvent>>(
                  future: _ashesiDates(),
                  builder: (context, snap) {
                    final dates = (snap.data ?? []).where((a) => !repo.events.any((e) => e.name == a.name && e.start == a.start)).toList();
                    if (dates.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.school_rounded),
                        label: Text('Add ${dates.length} Ashesi dates'),
                        onPressed: () {
                          for (final e in dates) {
                            repo.saveEvent(e);
                          }
                        },
                      ),
                    );
                  },
                ),
                if (repo.events.isEmpty) Panel(child: Text('No events yet. Add the next break or exam week.', style: B.body(14.5))),
                for (final e in repo.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.name, style: B.body(16, w: FontWeight.w700)),
                            Text('${e.start.day}/${e.start.month} to ${e.end.day}/${e.end.month} · ${_effect(e.factor)}', style: B.body(13, color: B.mute)),
                          ]),
                        ),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => repo.deleteEvent(e.id)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );

  Future<void> _add(BuildContext context) {
    final name = TextEditingController();
    DateTimeRange? range;
    var change = -30.0;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add an event', style: B.display(23)),
            const SizedBox(height: 12),
            TextField(controller: name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What is happening?')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range_rounded),
              label: Text(range == null ? 'Pick the dates' : '${range!.start.day}/${range!.start.month} to ${range!.end.day}/${range!.end.month}'),
              onPressed: () async {
                final now = DateTime.now();
                final r = await showDateRangePicker(context: ctx, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 400)));
                if (r != null) set(() => range = r);
              },
            ),
            const SizedBox(height: 14),
            Text(change == 0 ? 'About the same number of customers' : (change < 0 ? 'About ${-change.round()}% fewer customers' : 'About ${change.round()}% more customers'), style: B.body(15, w: FontWeight.w700)),
            Slider(value: change, min: -90, max: 100, divisions: 38, activeColor: B.gold, onChanged: (v) => set(() => change = v)),
            Text('Your best guess. Comparing it with what really sells will tell us how close it was.', style: B.body(13, color: B.mute)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || range == null) return;
                repo.saveEvent(ShopEvent(name: name.text.trim(), start: range!.start, end: range!.end, factor: 1 + change / 100));
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ======================= My numbers: the evidence the PRD asks for =======================
class _Evidence extends StatelessWidget {
  const _Evidence({required this.repo});
  final ShopRepo repo;

  ({List<String> header, List<List<String>> rows, Map<String, String> sum}) _data() {
    final real = repo.logs.where((l) => l.method != 'setup').toList();
    final days = real.map((l) => dayOnly(l.at)).toSet();
    final stats = repo.loggingStats;
    final errs = <double>[];
    final rows = <List<String>>[];
    for (final p in repo.products) {
      for (final c in weekChecks(p, repo.logsFor(p.id), repo.events, repo.today)) {
        errs.add(c.error);
        rows.add([p.label, '${c.weekStart.year}-${c.weekStart.month}-${c.weekStart.day}', c.predicted.toStringAsFixed(1), c.actual.toStringAsFixed(1), '${(c.error * 100).round()}%']);
      }
    }
    errs.sort();
    return (
      header: ['Product', 'Week starting', 'Predicted', 'Actual', 'Error'],
      rows: rows,
      sum: {
        'Days logged, last 7': '${repo.lastSevenLogged.where((x) => x).length} of 7',
        'Days logged, all time': '${days.length}',
        'Log entries': '${real.length}',
        for (final e in stats.entries) 'Median seconds per log (${e.key})': '${tidy(e.value.median)}s over ${e.value.entries}',
        'Median forecast error': errs.isEmpty ? 'not enough history yet' : '${(errs[errs.length ~/ 2] * 100).round()}%',
        'Items running low now': '${repo.warnings.length}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data();
    final csv = StringBuffer();
    d.sum.forEach((k, v) => csv.writeln('"$k","$v"'));
    csv.writeln();
    csv.writeln(d.header.join(','));
    for (final r in d.rows) {
      csv.writeln(r.map((x) => '"$x"').join(','));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My numbers')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
            Text('Only your own records, worked out on the spot. Copy them if you want to share them with someone.', style: B.body(14.5, color: B.mute)),
            const SizedBox(height: 12),
            Panel(
              child: Column(children: [
                for (final e in d.sum.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [Expanded(child: Text(e.key, style: B.body(14.5, color: B.mute))), Text(e.value, style: B.body(14.5, w: FontWeight.w700))]),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy as a spreadsheet (CSV)'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv.toString()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
          ]),
        ),
      ),
    );
  }
}
