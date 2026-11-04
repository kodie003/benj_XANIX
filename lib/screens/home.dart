import 'package:flutter/material.dart';

import '../core/repo.dart';
import 'product.dart';
import 'product_form.dart';
import 'shell.dart';
import 'ui.dart';

/// PRD Home: low-stock warnings with days left, this week's buying list summary,
/// and a "log today" button. An answer, not a dashboard.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repo, required this.shell});
  final ShopRepo repo;
  final ShellState shell;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shop = repo.shop!;
    if (repo.products.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 140), children: [
        Text(shop.name, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Empty(
          icon: Icons.inventory_2_outlined,
          text: 'Add the products you sell, with how many are on the shelf now. Start with your top 10.',
          action: 'Add your first product',
          onAction: () => showProductForm(context, repo),
        ),
      ]);
    }
    final warnings = repo.warnings;
    final buying = repo.rows.where((r) => r.$2.suggestedQty > 0).toList()
      ..sort((a, b) => (a.$2.daysLeft ?? 999).compareTo(b.$2.daysLeft ?? 999));
    final learning = repo.rows.where((r) => r.$2.learning).length;
    final week = repo.lastSevenLogged;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 140), children: [
      Row(children: [
        Expanded(child: Text(shop.name, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        _SyncChip(repo: repo),
      ]),
      const SizedBox(height: 12),
      if (!repo.loggedToday)
        FilledButton.icon(
          onPressed: () => shell.go(1),
          icon: const Icon(Icons.edit_note),
          label: const Padding(padding: EdgeInsets.all(12), child: Text("Log today's sales")),
        )
      else
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const ListTile(leading: Icon(Icons.check_circle), title: Text('Logged today. Well done.')),
        ),
      Section(
        title: warnings.isEmpty ? 'Nothing is running low' : 'Running low',
        child: warnings.isEmpty
            ? Text('benj will warn you here before anything runs out.', style: text.bodyMedium)
            : Column(children: [
                for (final (p, f) in warnings)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: urgencyColor(context, f)),
                      title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${units(p, f.stock)} on the shelf${daysLeftText(f) == null ? '' : ' · ${daysLeftText(f)}'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openProduct(context, repo, p),
                    ),
                  ),
              ]),
      ),
      Section(
        title: 'To buy this week',
        trailing: TextButton(onPressed: () => shell.go(2), child: const Text('Full list')),
        child: buying.isEmpty
            ? Text(learning > 0 ? 'Keep logging for a few days and the list will appear.' : 'You have enough of everything for this week.', style: text.bodyMedium)
            : Card(
                child: Column(children: [
                  for (final (p, f) in buying.take(3))
                    ListTile(dense: true, leading: const Icon(Icons.shopping_basket_outlined), title: Text(buyLine(p, f.suggestedQty))),
                  if (buying.length > 3) ListTile(dense: true, title: Text('and ${buying.length - 3} more…'), onTap: () => shell.go(2)),
                ]),
              ),
      ),
      Section(
        title: 'Days logged this week',
        child: Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: week[i] ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text('${week.where((d) => d).length} of 7'),
        ]),
      ),
      if (learning > 0)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text('Still learning $learning ${learning == 1 ? 'product' : 'products'}: benj needs 3 days of logs before it can forecast.', style: text.bodySmall),
        ),
    ]);
  }
}

/// Saved on the phone vs synced: owners on bad connections should know their logs are safe.
class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.repo});
  final ShopRepo repo;

  @override
  Widget build(BuildContext context) {
    final pending = repo.hasPendingWrites;
    return Chip(
      avatar: Icon(pending ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 18),
      label: Text(pending ? 'Saved on phone' : 'Synced'),
      visualDensity: VisualDensity.compact,
    );
  }
}
