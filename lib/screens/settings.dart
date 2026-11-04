import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../poddy/poddy.dart';
import 'product.dart';
import 'product_form.dart';
import 'ui.dart';

/// PRD Settings: shop details, restock day, products, the campus calendar (F6),
/// and the logging numbers the team reports to the judges.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo, required this.auth});
  final ShopRepo repo;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final shop = repo.shop;
        if (shop == null) return const Scaffold();
        final account = AuthService.accountLabel(auth.user);
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
            Section(
              title: 'Your shop',
              child: Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(shop.name),
                    subtitle: Text([if (shop.ownerName.isNotEmpty) shop.ownerName, if (shop.location.isNotEmpty) shop.location, if (shop.ownerPhone.isNotEmpty) shop.ownerPhone].join(' · ').ifEmpty('Add your name, location and phone')),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editShop(context, shop),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('Usual restock day'),
                    subtitle: Text(shop.restockDay == null ? 'Not set: benj plans a week at a time' : weekdays[shop.restockDay! - 1]),
                    trailing: DropdownButton<int?>(
                      value: shop.restockDay,
                      hint: const Text('Pick'),
                      onChanged: (d) => repo.saveShop(_copy(shop, restockDay: d, clearRestock: d == null)),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Not set')),
                        for (var i = 1; i <= 7; i++) DropdownMenuItem<int?>(value: i, child: Text(weekdays[i - 1])),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            Section(
              title: 'Products (${repo.products.length})',
              trailing: TextButton.icon(onPressed: () => showProductForm(context, repo), icon: const Icon(Icons.add), label: const Text('Add')),
              child: repo.products.isEmpty
                  ? const Text('No products yet.')
                  : Card(
                      child: Column(children: [
                        for (final p in repo.products)
                          ListTile(
                            dense: true,
                            title: Text(p.label),
                            subtitle: Text([p.unit, if (p.costPrice != null) 'you pay ${cedis(p.costPrice!)}', if (p.warningLevel != null) 'warn at ${qty(p.warningLevel!)}'].join(' · ')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openProduct(context, repo, p),
                          ),
                      ]),
                    ),
            ),
            Section(
              title: 'Campus calendar',
              trailing: TextButton.icon(onPressed: () => _addEvent(context), icon: const Icon(Icons.add), label: const Text('Add')),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Exams, breaks and events change how much you sell. benj adjusts your buying list for them. '
                  "Ashesi's official dates will be added by the team; add your own below.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (repo.events.isEmpty)
                  const Text('No events yet.')
                else
                  Card(
                    child: Column(children: [
                      for (final e in repo.events)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.event_outlined),
                          title: Text(e.name),
                          subtitle: Text('${_date(e.start)} to ${_date(e.end)} · ${_factorText(e.factor)}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Remove', onPressed: () => repo.deleteEvent(e.id)),
                        ),
                    ]),
                  ),
              ]),
            ),
            Section(title: 'Your logging this week', child: _LoggingNumbers(repo: repo)),
            Section(
              title: 'Account',
              child: Card(
                child: Column(children: [
                  if (account.isNotEmpty) ListTile(leading: const Icon(Icons.person_outline), title: Text('Signed in as $account')),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Credits'),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(title: const Text('Credits'), content: const Text(poddyCredit), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      auth.signOut();
                    },
                  ),
                ]),
              ),
            ),
            // The very last thing on the page, on purpose.
            const SizedBox(height: 32),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, side: BorderSide(color: Theme.of(context).colorScheme.error)),
              onPressed: () => _deleteAccount(context),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Padding(padding: EdgeInsets.all(12), child: Text('Delete account')),
            ),
          ]),
        );
      },
    );
  }

  /// Poddy is sad to see the owner go; the owner confirms; everything is deleted.
  Future<void> _deleteAccount(BuildContext context) async {
    final error = Theme.of(context).colorScheme.error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 170, width: 170, child: PoddyView(mood: 'sad')),
          Text("We're sorry to see you leave.", textAlign: TextAlign.center, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            'This deletes ${repo.shop?.name ?? 'your shop'}, all its products and every log, and your benj account. It cannot be undone.',
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep my account')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: error), onPressed: () => Navigator.pop(c, true), child: const Text('Delete everything')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // Firebase only allows deleting an account soon after signing in. Check before
    // touching any data, so nothing is half-deleted.
    if (!auth.signedInRecently) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Please sign in again first'),
          content: const Text('For your safety, sign out, sign back in, and then delete your account straight away.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      return;
    }
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await repo.deleteEverything();
      await auth.deleteAccount();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't delete everything: ${AuthService.friendly(e)} Check your connection and try again.")));
    }
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static String _factorText(double f) =>
      f >= 1 ? '${((f - 1) * 100).round()}% more customers' : '${((1 - f) * 100).round()}% fewer customers';

  Shop _copy(Shop s, {String? name, String? ownerName, String? location, String? ownerPhone, int? restockDay, bool clearRestock = false}) => Shop(
        name: name ?? s.name,
        ownerName: ownerName ?? s.ownerName,
        location: location ?? s.location,
        ownerPhone: ownerPhone ?? s.ownerPhone,
        restockDay: clearRestock ? null : (restockDay ?? s.restockDay),
        consentAt: s.consentAt,
      );

  Future<void> _editShop(BuildContext context, Shop shop) async {
    final name = TextEditingController(text: shop.name);
    final owner = TextEditingController(text: shop.ownerName);
    final location = TextEditingController(text: shop.location);
    final phone = TextEditingController(text: shop.ownerPhone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Your shop'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Business name')),
            TextField(controller: owner, decoration: const InputDecoration(labelText: 'Your name')),
            TextField(controller: location, decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. Berekuso')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, name.text.trim().isNotEmpty), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await repo.saveShop(_copy(shop, name: name.text.trim(), ownerName: owner.text.trim(), location: location.text.trim(), ownerPhone: phone.text.trim()));
    }
  }

  Future<void> _addEvent(BuildContext context) async {
    final name = TextEditingController();
    DateTimeRange? range;
    var factor = 0.7;
    final options = <(double, String)>[(0.4, 'Much quieter'), (0.7, 'Quieter'), (1.3, 'Busier'), (1.6, 'Much busier')];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add an event'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'What is happening?', hintText: 'e.g. Mid-semester break')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(range == null ? 'Pick the dates' : '${_date(range!.start)} to ${_date(range!.end)}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final r = await showDateRangePicker(context: c, firstDate: now.subtract(const Duration(days: 60)), lastDate: now.add(const Duration(days: 365)));
                  if (r != null) set(() => range = r);
                },
              ),
              const SizedBox(height: 12),
              const Text('Customers that week'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (f, label) in options) ChoiceChip(label: Text(label), selected: factor == f, onSelected: (_) => set(() => factor = f)),
              ]),
              const SizedBox(height: 6),
              Text(_factorText(factor), style: Theme.of(c).textTheme.bodySmall),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, name.text.trim().isNotEmpty && range != null), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && range != null) {
      await repo.saveEvent(ShopEvent(name: name.text.trim(), start: range!.start, end: range!.end, factor: factor));
    }
  }
}

/// PRD riskiest assumption: days logged out of 7 and seconds per entry, by input method.
class _LoggingNumbers extends StatelessWidget {
  const _LoggingNumbers({required this.repo});
  final ShopRepo repo;

  @override
  Widget build(BuildContext context) {
    final days = repo.lastSevenLogged.where((d) => d).length;
    final stats = repo.loggingStats;
    return Card(
      child: Column(children: [
        ListTile(leading: const Icon(Icons.calendar_today_outlined), title: Text('Logged on $days of the last 7 days'), subtitle: const Text('Goal: 5 of 7')),
        for (final e in stats.entries)
          ListTile(
            leading: Icon(e.key == 'tap' ? Icons.touch_app_outlined : Icons.keyboard_outlined),
            title: Text('${e.key == 'tap' ? 'Tapping' : 'Typing'}: about ${e.value.median.round()} seconds per log'),
            subtitle: Text('${e.value.entries} entries · goal: under 60 seconds'),
          ),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
