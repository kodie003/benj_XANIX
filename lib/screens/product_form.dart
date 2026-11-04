import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models.dart';
import '../core/reader.dart';
import '../core/repo.dart';
import '../core/voice_stub.dart' if (dart.library.js_interop) '../core/voice_web.dart';
import '../poddy/poddy.dart';

/// F1 add or edit a product, on its own page. Three ways in: type it, say it, or
/// take a photo (a label, a shelf, or a stock-book page). Speech and photos are read
/// by Gemini (Firebase AI Logic) into the form; the owner checks before saving.
Future<void> showProductForm(BuildContext context, ShopRepo repo, {Product? editing}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductFormPage(repo: repo, editing: editing)));

enum _Way { type, speak, photo }

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, required this.repo, this.editing});
  final ShopRepo repo;
  final Product? editing;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _size = TextEditingController(text: widget.editing?.size);
  final _onHand = TextEditingController();
  late final _cost = TextEditingController(text: _num(widget.editing?.costPrice));
  late final _sell = TextEditingController(text: _num(widget.editing?.sellPrice));
  late final _warn = TextEditingController(text: _num(widget.editing?.warningLevel));
  late String _unit = widget.editing?.unit ?? '';
  _Way _way = _Way.type;
  String? _error, _note;
  int _added = 0;

  // Speaking
  final _heard = TextEditingController();
  bool _listening = false, _reading = false;

  // Photo
  List<ProductDraft> _found = [];
  final _pick = <int>{};

  static String _num(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());
  static double? _parse(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());
  bool get _editing => widget.editing != null;

  // ---------------------------------------------------------------- saving

  Product _product() => Product(
        id: widget.editing?.id ?? '',
        name: _name.text.trim(),
        unit: _unit,
        size: _size.text.trim(),
        costPrice: _parse(_cost.text),
        sellPrice: _parse(_sell.text),
        warningLevel: _parse(_warn.text),
      );

  Future<bool> _save() async {
    if (_name.text.trim().isEmpty) return _fail('Give the product a name.');
    if (_unit.isEmpty) return _fail('Pick how it comes: bag, pack, carton…');
    if (_editing) {
      await widget.repo.saveProduct(_product());
    } else {
      await widget.repo.addProduct(_product(), _parse(_onHand.text) ?? 0);
    }
    return true;
  }

  bool _fail(String m) {
    setState(() => _error = m);
    return false;
  }

  void _clear() {
    for (final c in [_name, _size, _onHand, _cost, _sell, _warn, _heard]) {
      c.clear();
    }
    _unit = '';
    _error = null;
    _note = null;
  }

  void _fill(ProductDraft d) {
    _name.text = d.name;
    _size.text = d.size;
    if (d.unit.isNotEmpty) _unit = d.unit;
    if (d.onHand != null) _onHand.text = _num(d.onHand);
    if (d.costPrice != null) _cost.text = _num(d.costPrice);
    if (d.sellPrice != null) _sell.text = _num(d.sellPrice);
  }

  // ---------------------------------------------------------------- speaking

  void _toggleMic() {
    if (_listening) {
      Voice.stop();
      return;
    }
    setState(() {
      _listening = true;
      _note = null;
    });
    Voice.start(
      (text, _) => setState(() => _heard.text = text),
      (err) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          if (err == 'not-allowed') _note = 'benj needs the microphone. Allow it in your browser, or type below.';
          if (err == 'no-speech') _note = "I didn't hear anything. Tap the mic and try again.";
        });
        if (err.isEmpty && _heard.text.trim().isNotEmpty) _understand();
      },
    );
  }

  Future<void> _understand() async {
    final said = _heard.text.trim();
    if (said.isEmpty) {
      setState(() => _note = 'Say or type the product first.');
      return;
    }
    setState(() {
      _reading = true;
      _note = null;
    });
    try {
      final found = await ProductReader.fromSpeech(said);
      setState(() {
        if (found.isEmpty) {
          _note = "I couldn't pick out a product. Try: \"Rice, 1 kg bag, 30 on the shelf, I pay 18 cedis\".";
        } else {
          _fill(found.first);
          _note = 'I filled in the form below. Check it, then save.';
        }
      });
    } catch (_) {
      setState(() => _note = "I couldn't read that right now. Check your connection, or type it below.");
    }
    if (mounted) setState(() => _reading = false);
  }

  // ---------------------------------------------------------------- photo

  Future<void> _photo(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _reading = true;
      _note = null;
      _found = [];
      _pick.clear();
    });
    try {
      final found = await ProductReader.fromPhoto(bytes, x.mimeType ?? 'image/jpeg');
      setState(() {
        if (found.isEmpty) {
          _note = "I couldn't read a product in that photo. Try closer, in good light, or type it below.";
        } else if (found.length == 1) {
          _fill(found.first);
          _note = 'I filled in the form below. Check it, then save.';
        } else {
          _found = found;
          _pick.addAll(List.generate(found.length, (i) => i));
          _note = 'I found ${found.length} products. Untick any that are wrong.';
        }
      });
    } catch (_) {
      setState(() => _note = "I couldn't read that photo right now. Check your connection, or type it below.");
    }
    if (mounted) setState(() => _reading = false);
  }

  Future<void> _addFound() async {
    var n = 0;
    for (final i in _pick.toList()..sort()) {
      final d = _found[i];
      await widget.repo.addProduct(
        Product(id: '', name: d.name, unit: d.unit.isEmpty ? 'piece' : d.unit, size: d.size, costPrice: d.costPrice, sellPrice: d.sellPrice),
        d.onHand ?? 0,
      );
      n++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $n ${n == 1 ? 'product' : 'products'}.')));
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------- page

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit ${widget.editing!.label}' : 'Add a product')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          if (!_editing) ...[
            Text('How do you want to add it?', style: text.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<_Way>(
              segments: const [
                ButtonSegment(value: _Way.type, icon: Icon(Icons.keyboard_outlined), label: Text('Type')),
                ButtonSegment(value: _Way.speak, icon: Icon(Icons.mic_none), label: Text('Speak')),
                ButtonSegment(value: _Way.photo, icon: Icon(Icons.photo_camera_outlined), label: Text('Photo')),
              ],
              selected: {_way},
              onSelectionChanged: (s) => setState(() {
                _way = s.first;
                _note = null;
              }),
            ),
            const SizedBox(height: 14),
            if (_way == _Way.speak) _speakPanel(text, scheme),
            if (_way == _Way.photo) _photoPanel(text, scheme),
            if (_reading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3)), SizedBox(width: 12), Text('Reading…')])),
            if (_note != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_note!, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600))),
            if (_found.isNotEmpty) _foundList(text),
            if (_added > 0) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('$_added added. Add the next one.', style: TextStyle(color: scheme.primary))),
          ],
          if (_found.isEmpty) ..._form(text),
        ]),
      ),
    );
  }

  Widget _speakPanel(TextTheme text, ColorScheme scheme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 120, child: PoddyView(mood: _listening ? 'present' : 'hello')),
            Text(
              Voice.supported ? 'Tap the mic and say it, like: "Rice, 1 kg bag, 30 on the shelf, I pay 18 cedis."' : "This browser can't listen. Type what you'd say below.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (Voice.supported)
              Center(
                child: FilledButton.icon(
                  onPressed: _reading ? null : _toggleMic,
                  style: FilledButton.styleFrom(backgroundColor: _listening ? scheme.error : null),
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Padding(padding: const EdgeInsets.all(12), child: Text(_listening ? 'Stop' : 'Tap to speak')),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _heard,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'What I heard (you can fix it)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _reading || _listening ? null : _understand, child: const Text('Fill the form from this')),
          ]),
        ),
      );

  Widget _photoPanel(TextTheme text, ColorScheme scheme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Take a photo of the product, its label or price tag, or a page of your stock book.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _reading ? null : () => _photo(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reading ? null : () => _photo(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ),
            ]),
          ]),
        ),
      );

  Widget _foundList(TextTheme text) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
          child: Column(children: [
            for (final (i, d) in _found.indexed)
              CheckboxListTile(
                value: _pick.contains(i),
                onChanged: (v) => setState(() => v == true ? _pick.add(i) : _pick.remove(i)),
                title: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if (d.unit.isNotEmpty) d.unit,
                  if (d.onHand != null) '${_num(d.onHand)} on the shelf',
                  if (d.costPrice != null) 'you pay GHS ${_num(d.costPrice)}',
                  if (d.sellPrice != null) 'sells for GHS ${_num(d.sellPrice)}',
                ].join(' · ')),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _pick.isEmpty ? null : _addFound,
          child: Padding(padding: const EdgeInsets.all(12), child: Text('Add ${_pick.length} ${_pick.length == 1 ? 'product' : 'products'}')),
        ),
        TextButton(onPressed: () => setState(() => _found = []), child: const Text('Start again')),
      ]);

  List<Widget> _form(TextTheme text) {
    Widget field(TextEditingController c, String label, {String? hint, bool number = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            textCapitalization: number ? TextCapitalization.none : TextCapitalization.words,
            decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
          ),
        );
    return [
      if (!_editing) Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text('Product details', style: text.titleMedium)),
      field(_name, 'Name', hint: 'e.g. Rice'),
      field(_size, 'Size (optional)', hint: 'e.g. 1 kg, 4.5 kg, 500 ml'),
      Text('It comes as a', style: text.labelLarge),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final u in kUnits) ChoiceChip(label: Text(u), selected: _unit == u, onSelected: (_) => setState(() => _unit = u)),
      ]),
      const SizedBox(height: 16),
      if (!_editing) field(_onHand, 'On the shelf now', hint: '0', number: true),
      Row(children: [
        Expanded(child: field(_cost, 'You pay (GHS)', hint: 'optional', number: true)),
        const SizedBox(width: 10),
        Expanded(child: field(_sell, 'You sell for (GHS)', hint: 'optional', number: true)),
      ]),
      field(_warn, 'Warn me when only this many are left', hint: 'leave blank and benj will suggest', number: true),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
      if (_editing)
        FilledButton(
          onPressed: () async {
            if (await _save() && mounted) Navigator.pop(context);
          },
          child: const Padding(padding: EdgeInsets.all(14), child: Text('Save')),
        )
      else
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                if (await _save()) {
                  setState(() {
                    _added++;
                    _clear();
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
                if (await _save() && mounted) Navigator.pop(context);
              },
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Save')),
            ),
          ),
        ]),
    ];
  }
}
