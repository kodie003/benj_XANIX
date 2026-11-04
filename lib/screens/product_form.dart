import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repo.dart';
import '../core/theme.dart';

/// F1: name, unit, size, and how many are on the shelf. Cost is optional; it only
/// feeds the budget-aware list.
Future<void> openProductForm(BuildContext context, ShopRepo repo, {Product? existing}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ProductForm(repo: repo, existing: existing),
      ),
    );

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.repo, this.existing});
  final ShopRepo repo;
  final Product? existing;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _size = TextEditingController(text: widget.existing?.size ?? '');
  late final _cost = TextEditingController(text: widget.existing?.costPrice?.toString() ?? '');
  late final _sell = TextEditingController(text: widget.existing?.sellPrice?.toString() ?? '');
  final _onHand = TextEditingController();
  late String _unit = widget.existing?.unit ?? 'bag';
  String? _error;

  Future<void> _save({bool another = false}) async {
    if (_name.text.trim().isEmpty) return setState(() => _error = 'What is it called?');
    final p = Product(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      unit: _unit,
      size: _size.text.trim(),
      costPrice: double.tryParse(_cost.text),
      sellPrice: double.tryParse(_sell.text),
      warningLevel: widget.existing?.warningLevel,
    );
    if (widget.existing == null) {
      await widget.repo.addProduct(p, double.tryParse(_onHand.text) ?? 0);
    } else {
      await widget.repo.saveProduct(p);
    }
    if (!mounted) return;
    if (another) {
      setState(() {
        _name.clear();
        _size.clear();
        _cost.clear();
        _sell.clear();
        _onHand.clear();
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.existing == null ? 'Add a product' : 'Edit product', style: B.display(23)),
            const SizedBox(height: 14),
            TextField(controller: _name, autofocus: widget.existing == null, textCapitalization: TextCapitalization.words, style: B.body(16), decoration: const InputDecoration(labelText: 'Name', hintText: 'Rice')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _size, style: B.body(16), decoration: const InputDecoration(labelText: 'Size (optional)', hintText: '4.5 kg'))),
              if (widget.existing == null) ...[
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _onHand, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: B.body(16), decoration: const InputDecoration(labelText: 'On the shelf now'))),
              ],
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final u in kUnits)
                ChoiceChip(
                  label: Text(u),
                  selected: _unit == u,
                  selectedColor: B.gold,
                  labelStyle: B.body(14, w: FontWeight.w700, color: _unit == u ? const Color(0xFF241600) : B.text),
                  onSelected: (_) => setState(() => _unit = u),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: B.body(16), decoration: const InputDecoration(labelText: 'You pay (optional)', prefixText: 'GH₵ '))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _sell, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: B.body(16), decoration: const InputDecoration(labelText: 'You sell (optional)', prefixText: 'GH₵ '))),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: B.body(14, color: B.coral, w: FontWeight.w600))),
            const SizedBox(height: 14),
            Row(children: [
              if (widget.existing == null) ...[
                Expanded(child: OutlinedButton(onPressed: () => _save(another: true), child: const Text('Save, add another'))),
                const SizedBox(width: 10),
              ],
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Save'))),
            ]),
          ]),
        ),
      );
}
