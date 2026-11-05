import 'package:flutter/material.dart';

import '../core/repo.dart';
import 'assistant.dart';
import 'poddy.dart';

/// "Need something?": the owner types a question; Poddy answers in a few words and,
/// for "how do I…" questions, offers "Show me", which returns the section to tour.
Future<String?> showAskPoddy(BuildContext context, ShopRepo repo) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AskSheet(repo: repo),
      ),
    );

class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.repo});
  final ShopRepo repo;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _q = TextEditingController();
  bool _busy = false;
  PoddyAnswer? _answer;
  String? _error;

  static const _ideas = ['How do I add a product?', 'What should I buy this week?', 'How do I delete a product?', 'What is running low?'];

  Future<void> _ask([String? text]) async {
    final q = (text ?? _q.text).trim();
    if (q.isEmpty) return;
    _q.text = q;
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });
    try {
      final a = await PoddyAssistant.ask(q, widget.repo);
      if (mounted) setState(() => _answer = a);
    } catch (_) {
      // The owner may have tapped away while Poddy was thinking.
      if (mounted) setState(() => _error = "I can't answer right now. Check your connection, or tap Tips.");
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = _answer;
    // A tap anywhere closes the sheet. The field, chips and buttons keep their own taps.
    void close() => Navigator.pop(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: close,
      child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          SizedBox(height: 120, child: PoddyView(mood: _busy ? 'present' : (a != null ? 'welcome' : 'hello'), onTap: close)),
          Text('Need something?', textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 10),
          if (a == null && !_busy)
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (final i in _ideas) ActionChip(label: Text(i), onPressed: () => _ask(i)),
            ]),
          const SizedBox(height: 10),
          TextField(
            controller: _q,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _busy ? null : _ask(),
            decoration: InputDecoration(
              labelText: 'Ask Poddy',
              hintText: 'e.g. How do I record what I bought?',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(tooltip: 'Send', icon: const Icon(Icons.send), onPressed: _busy ? null : _ask),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
          if (a != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Text(a.answer, style: text.bodyLarge),
            ),
            if (a.section != 'none') ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, a.section),
                icon: const Icon(Icons.near_me_outlined),
                label: const Padding(padding: EdgeInsets.all(10), child: Text('Show me')),
              ),
            ],
          ],
        ]),
      ),
      ),
    );
  }
}
