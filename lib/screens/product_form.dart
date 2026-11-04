import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repo.dart';

/// F1: add a product with unit and size, how many are on the shelf, optional prices,
/// and an optional warning level (blank = benj suggests one from sales).
Future<void> showProductForm(BuildContext context, ShopRepo repo, {Product? editing}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ProductForm(repo: repo, editing: editing),
      ),
    );

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.repo, this.editing});
  final ShopRepo repo;
  final Product? editing;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _size = TextEditingController(text: widget.editing?.size);
  final _onHand = TextEditingController();
  late final _cost = TextEditingController(text: _num(widget.editing?.costPrice));
  late final _sell = TextEditingController(text: _num(widget.editing?.sellPrice));
  late final _warn = TextEditingController(text: _num(widget.editing?.warningLevel));
  late String _unit = widget.editing?.unit ?? '';
  String? _error;
  int _added = 0;

  static String _num(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());
  static double? _parse(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());

  Future<bool> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the product a name.');
      return false;
    }
    if (_unit.isEmpty) {
      setState(() => _error = 'Pick how it comes: bag, pack, carton…');
      return false;
    }
    final p = Product(
      id: widget.editing?.id ?? '',
      name: _name.text.trim(),
      unit: _unit,
      size: _size.text.trim(),
      costPrice: _parse(_cost.text),
      sellPrice: _parse(_sell.text),
      warningLevel: _parse(_warn.text),
    );
    if (widget.editing != null) {
      await widget.repo.saveProduct(p);
    } else {
      await widget.repo.addProduct(p, _parse(_onHand.text) ?? 0);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    Widget field(TextEditingController c, String label, {String? hint, bool number = false, String? helper}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            textCapitalization: number ? TextCapitalization.none : TextCapitalization.words,
            decoration: InputDecoration(labelText: label, hintText: hint, helperText: helper, border: const OutlineInputBorder()),
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(editing ? 'Edit product' : 'Add a product', style: Theme.of(context).textTheme.titleLarge),
          if (_added > 0) Text('$_added added. Add the next one.', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          field(_name, 'Name', hint: 'e.g. Rice'),
          field(_size, 'Size (optional)', hint: 'e.g. 1 kg, 4.5 kg, 500 ml'),
          Text('It comes as a', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final u in kUnits) ChoiceChip(label: Text(u), selected: _unit == u, onSelected: (_) => setState(() => _unit = u)),
          ]),
          const SizedBox(height: 14),
          if (!editing) field(_onHand, 'On the shelf now', hint: '0', number: true),
          Row(children: [
            Expanded(child: field(_cost, 'You pay (GHS)', hint: 'optional', number: true)),
            const SizedBox(width: 10),
            Expanded(child: field(_sell, 'You sell for (GHS)', hint: 'optional', number: true)),
          ]),
          field(_warn, 'Warn me when only this many are left', hint: 'leave blank and benj will suggest', number: true),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (editing)
            FilledButton(
              onPressed: () async {
                if (await _save() && context.mounted) Navigator.pop(context);
              },
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Save')),
            )
          else
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (await _save()) {
                      setState(() {
                        _added++;
                        _error = null;
                        for (final c in [_name, _size, _onHand, _cost, _sell, _warn]) {
                          c.clear();
                        }
                      });
                    }
                  },
                  child: const Padding(padding: EdgeInsets.all(12), child: Text('Save, add another')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (await _save() && context.mounted) Navigator.pop(context);
                  },
                  child: const Padding(padding: EdgeInsets.all(12), child: Text('Save')),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}
