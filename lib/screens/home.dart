import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

String cedis(num v) => 'GHS ${v.round()}';

/// "Tell, don't show": numbers on top, then this week's 3 actions, each with why.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final data = state.insights;
    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null) Text(state.error!, style: const TextStyle(color: Colors.red)),
          if (data != null) ..._content(context, data),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, Map<String, dynamic> data) {
    final s = data['summary'] as Map<String, dynamic>;
    final actions = List<Map<String, dynamic>>.from(data['actions']);
    final more = List<Map<String, dynamic>>.from(data['more']);
    final lastWeek = (s['last_week_sales'] as num);
    final change = lastWeek > 0 ? ((s['week_sales'] - lastWeek) / lastWeek * 100).round() : null;
    final text = Theme.of(context).textTheme;

    return [
      Text(data['business'], style: text.titleLarge),
      const SizedBox(height: 8),
      Row(children: [
        _Stat('Today', cedis(s['today_sales'])),
        _Stat('Last 7 days', cedis(s['week_sales']), note: change == null ? null : '${change >= 0 ? '+' : ''}$change% vs week before'),
        _Stat('Profit (est.)', cedis(s['week_profit'])),
      ]),
      const SizedBox(height: 20),
      Text('Do these 3 things this week', style: text.titleMedium),
      const SizedBox(height: 4),
      for (final (i, a) in actions.indexed) _ActionCard(number: i + 1, action: a, state: state),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Send to WhatsApp'),
          onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(data['whatsapp'])}')),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy weekly message'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: data['whatsapp']));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
          },
        ),
      ]),
      if (more.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('${more.length} more things we noticed'),
          children: [
            for (final a in more)
              ListTile(contentPadding: EdgeInsets.zero, title: Text(a['title']), subtitle: Text(a['why'])),
          ],
        ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Preview the weekly WhatsApp message'),
        children: [SelectableText(data['whatsapp'])],
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.note});
  final String label, value;
  final String? note;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              if (note != null) Text(note!, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.number, required this.action, required this.state});
  final int number;
  final Map<String, dynamic> action;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final title = action['title'] as String;
    final done = state.actedOn.contains(title);
    final impact = (action['impact'] as num);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 14, child: Text('$number')),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          ]),
          const SizedBox(height: 6),
          Text('Why: ${action['why']}'),
          Row(children: [
            if (impact > 0) Text('About ${cedis(impact)} at stake', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            // FR-E2: did the owner act on it? This is the behaviour we measure.
            FilterChip(
              label: Text(done ? 'Done' : 'I did this'),
              selected: done,
              onSelected: (_) => state.toggleActed(title),
            ),
          ]),
        ]),
      ),
    );
  }
}
