import 'package:flutter/material.dart';

import '../core/categories.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../poddy/poddy.dart';

void openCategories(BuildContext context, ShopRepo repo, {bool suggest = false}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CategoriesPage(repo: repo, suggest: suggest)));

/// The owner's product categories. Poddy suggests them; the owner renames, moves and
/// removes anything. Nothing is saved until they tap Save.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.repo, this.suggest = false});
  final ShopRepo repo;

  /// Ask Poddy straight away when the page opens.
  final bool suggest;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _draft = <String, String>{};
  bool _thinking = false;
  String? _note, _error;

  ShopRepo get _repo => widget.repo;
  String _of(Product p) => _draft[p.id] ?? p.category;
  Map<String, String> get _changes => {
        for (final p in _repo.products)
          if (_of(p) != p.category) p.id: _of(p),
      };
  List<(String, List<Product>)> get _groups => groupByCategory(_repo.products, of: _of);
  List<String> get _names => [
        for (final (name, _) in _groups)
          if (name != kNotSorted) name,
      ];

  @override
  void initState() {
    super.initState();
    if (widget.suggest) WidgetsBinding.instance.addPostFrameCallback((_) => _suggest());
  }

  /// Sorts whatever isn't sorted yet; when everything is, Poddy looks at the lot again.
  Future<void> _suggest() async {
    final unsorted = [for (final p in _repo.products) if (_of(p).isEmpty) p];
    final targets = unsorted.isEmpty ? _repo.products : unsorted;
    if (targets.isEmpty) return;
    setState(() {
      _thinking = true;
      _error = _note = null;
    });
    try {
      final found = await CategorySuggester.suggest(targets, _names);
      if (!mounted) return;
      setState(() {
        _draft.addAll(found);
        if (found.isEmpty) {
          _error = "I couldn't sort these. You can sort them yourself below.";
        } else {
          _note = 'My suggestions. Move or rename anything, then tap Save.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = "I can't sort them right now. Try again soon, or sort them yourself below.");
    }
    if (mounted) setState(() => _thinking = false);
  }

  Future<void> _move(Product p) async {
    final current = _of(p);
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Move ${p.label} to', style: Theme.of(c).textTheme.titleMedium)),
          for (final n in _names)
            if (n != current) ListTile(title: Text(n), onTap: () => Navigator.pop(c, n)),
          ListTile(leading: const Icon(Icons.add), title: const Text('New category'), onTap: () => Navigator.pop(c, '+')),
          if (current.isNotEmpty) ListTile(leading: const Icon(Icons.remove_circle_outline), title: const Text(kNotSorted), onTap: () => Navigator.pop(c, '')),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    final target = choice == '+' ? await _askName('New category', '') : choice;
    if (target == null || !mounted) return;
    setState(() => _draft[p.id] = matchCategory(target, _names));
  }

  Future<void> _rename(String name) async {
    final typed = await _askName('Rename category', name);
    if (typed == null || typed.isEmpty || !mounted) return;
    final others = [for (final n in _names) if (n != name) n];
    _setAll(name, matchCategory(typed, others));
  }

  void _setAll(String from, String to) => setState(() {
        for (final p in _repo.products) {
          if (_of(p) == from) _draft[p.id] = to;
        }
      });

  Future<String?> _askName(String title, String start) => showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(title: title, start: start),
      );

  Future<void> _save() async {
    await _repo.setCategories(_changes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categories saved.')));
    Navigator.pop(context);
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('Your category changes will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final changed = _changes.isNotEmpty;
        return PopScope(
          canPop: !changed,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Product categories')),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: changed && !_thinking ? _save : null,
                  child: const Padding(padding: EdgeInsets.all(12), child: Text('Save')),
                ),
              ),
            ),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              SizedBox(height: 110, child: PoddyView(mood: _thinking ? 'present' : 'hello')),
              Text(
                _thinking ? 'Studying your products…' : (_note ?? (_names.isEmpty ? 'I can sort your products into categories.' : 'Your categories.')),
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _thinking || _repo.products.isEmpty ? null : _suggest,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(_groups.any((g) => g.$1 == kNotSorted) ? 'Suggest categories' : 'Suggest again'),
                ),
              ),
              const SizedBox(height: 12),
              for (final (name, products) in _groups)
                Card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                      child: Row(children: [
                        Expanded(child: Text('$name (${products.length})', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                        if (name != kNotSorted) ...[
                          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Rename $name', onPressed: () => _rename(name)),
                          IconButton(icon: const Icon(Icons.close), tooltip: 'Remove $name', onPressed: () => _setAll(name, '')),
                        ],
                      ]),
                    ),
                    for (final p in products)
                      ListTile(
                        dense: true,
                        title: Text(p.label),
                        trailing: TextButton(onPressed: () => _move(p), child: Text('Move', semanticsLabel: 'Move ${p.label}')),
                      ),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.start});
  final String title, start;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.start);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _name,
          autofocus: true,
          maxLength: kCategoryMax,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Category name', hintText: 'e.g. Toiletries'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, cleanCategory(_name.text)), child: const Text('OK')),
        ],
      );
}
