import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models.dart';
import '../core/phrases.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import '../core/voice_parser.dart';
import '../fx/fx_bridge_stub.dart' if (dart.library.js_interop) '../fx/fx_bridge_web.dart' as bridge;
import '../fx/fx_view.dart';
import 'log_screen.dart';

/// Rows the owner confirms before anything is saved. Nothing heard or read goes
/// into the stock book without a human saying yes.
class _Row {
  _Row(this.product, this.quantity, this.type);
  Product product;
  double quantity;
  String type;
}

const _typeNames = {'sale': 'Sold', 'count': 'Counted', 'restock': 'Bought'};

class _ConfirmList extends StatelessWidget {
  const _ConfirmList({required this.rows, required this.products, required this.onChanged});
  final List<_Row> rows;
  final List<Product> products;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              color: B.raised,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    DropdownButton<String>(
                      value: row.product.id,
                      isExpanded: true,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: B.raised,
                      style: B.body(15, w: FontWeight.w700),
                      items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.label, overflow: TextOverflow.ellipsis))],
                      onChanged: (id) {
                        row.product = products.firstWhere((p) => p.id == id);
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 2),
                    DropdownButton<String>(
                      value: row.type,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: B.raised,
                      style: B.body(13, color: B.gold, w: FontWeight.w700),
                      items: [for (final e in _typeNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                      onChanged: (t) {
                        row.type = t!;
                        onChanged();
                      },
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: TextFormField(
                    key: ObjectKey(row),
                    initialValue: '${tidy(row.quantity)}',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: B.display(20),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                    onChanged: (v) => row.quantity = double.tryParse(v) ?? row.quantity,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    rows.remove(row);
                    onChanged();
                  },
                ),
              ]),
            ),
          ),
      ]);
}

// ======================= Voice (F9) =======================

Future<void> openVoice(BuildContext context, ShopRepo repo) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _VoiceScreen(repo: repo), fullscreenDialog: true));

class _VoiceScreen extends StatefulWidget {
  const _VoiceScreen({required this.repo});
  final ShopRepo repo;

  @override
  State<_VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<_VoiceScreen> {
  final _orb = FxController();
  final _typed = TextEditingController();
  final _started = DateTime.now();
  String _heard = '';
  bool _listening = false;
  String? _problem;
  List<_Row> _rows = [];

  @override
  void initState() {
    super.initState();
    if (bridge.voiceSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
    } else {
      _problem = 'This browser can\'t listen. Type it instead, or open benj in Chrome.';
    }
  }

  void _listen() {
    setState(() {
      _listening = true;
      _problem = null;
      _heard = '';
      _rows = [];
    });
    _orb.send({'state': 'listen', 'mic': true});
    bridge.voiceStart((text, isFinal) {
      if (!mounted) return;
      setState(() => _heard = text);
      if (isFinal) _parse(text);
    }, (err) {
      if (!mounted) return;
      _orb.send({'mic': false, 'state': _rows.isEmpty ? 'idle' : 'confirm'});
      setState(() {
        _listening = false;
        if (err == 'not-allowed' || err == 'service-not-allowed') _problem = 'Allow the microphone to speak your log, or type it below.';
        if (err == 'network') _problem = 'Voice needs a connection. Type it below, it saves offline.';
        if (err == 'no-speech' || (err.isEmpty && _heard.isEmpty)) _problem = 'I didn\'t catch that. Tap the orb and try again.';
      });
    });
  }

  void _parse(String text) {
    final parsed = parseSpeech(text, widget.repo.products);
    _orb.send({'state': parsed.isEmpty ? 'error' : 'confirm'});
    setState(() {
      _rows = [for (final e in parsed) _Row(e.product, e.quantity, e.type)];
      _problem = null;
      if (parsed.isEmpty) _problem = 'I heard "$text" but couldn\'t match a product and a number. Try "sold five small rice".';
    });
  }

  Future<void> _confirm() async {
    final seconds = DateTime.now().difference(_started).inSeconds;
    final now = DateTime.now();
    final list = [for (final (i, r) in _rows.indexed) StockLog(product: r.product.id, at: now, type: r.type, quantity: r.quantity, method: 'voice', secondsTaken: i == 0 ? seconds : null)];
    await saveWithGlow(context, widget.repo.addLogs(list), 'Got it. ${list.length} ${list.length == 1 ? 'item' : 'items'} logged.');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    bridge.voiceStop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Speak your log')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                GestureDetector(
                  onTap: _listening
                      ? bridge.voiceStop
                      : (bridge.voiceSupported ? _listen : null),
                  child: SizedBox(height: 280, child: FxView(kind: 'orb', config: const {'state': 'idle'}, controller: _orb, fallback: const Icon(Icons.mic_rounded, size: 90, color: B.teal))),
                ),
                Text(_listening ? 'Listening…' : (_rows.isEmpty ? 'Tap the orb and say it' : 'Is this right?'), textAlign: TextAlign.center, style: B.display(23)),
                const SizedBox(height: 6),
                Text(_heard.isEmpty ? 'Try: "sold five small rice and two noodles"' : '"$_heard"', textAlign: TextAlign.center, style: B.body(15, color: B.mute)),
                if (_problem != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_problem!, textAlign: TextAlign.center, style: B.body(14, color: B.gold, w: FontWeight.w600))),
                const SizedBox(height: 16),
                if (_rows.isNotEmpty) ...[
                  _ConfirmList(rows: _rows, products: widget.repo.products, onChanged: () => setState(() {})),
                  FilledButton(onPressed: _rows.isEmpty ? null : _confirm, child: const Text('Yes, save it')),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _typed,
                  style: B.body(15),
                  decoration: InputDecoration(
                    labelText: 'Or type it the same way',
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: () => _parse(_typed.text)),
                  ),
                  onSubmitted: _parse,
                ),
              ],
            ),
          ),
        ),
      );
}

// ======================= Photo (F10) =======================

Future<void> openPhoto(BuildContext context, ShopRepo repo) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PhotoScreen(repo: repo), fullscreenDialog: true));

class _PhotoScreen extends StatefulWidget {
  const _PhotoScreen({required this.repo});
  final ShopRepo repo;

  @override
  State<_PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<_PhotoScreen> {
  final _started = DateTime.now();
  Uint8List? _bytes;
  String _mime = 'image/jpeg';
  bool _reading = false;
  String? _note;
  List<_Row> _rows = [];

  Future<void> _take(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 72);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() {
      _bytes = b;
      _mime = x.mimeType ?? 'image/jpeg';
      _reading = true;
      _note = null;
      _rows = [];
    });
    await _read(b);
  }

  /// Gemini reads the handwriting; the owner always checks the result. If it can't be
  /// reached, the photo stays beside an empty list so the page can still be typed in.
  Future<void> _read(Uint8List bytes) async {
    final products = widget.repo.products;
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.8-flash',
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      final prompt = 'This is a photo of a handwritten stock book page from a small shop in Ghana. '
          'Read only what is written today or on the latest date. Return a JSON array of objects with keys '
          '"product" (one of these exact names: ${products.map((p) => p.label).join(' | ')}), "quantity" (number), '
          'and "type" ("sale" if units were sold, "restock" if bought or received, "count" if it is a closing or remaining count). '
          'Leave out anything you cannot read clearly, and products not in the list. Do not guess.';
      final res = await model.generateContent([Content.multi([TextPart(prompt), InlineDataPart(_mime, bytes)])]).timeout(const Duration(seconds: 45));
      final raw = (res.text ?? '[]').replaceAll('```json', '').replaceAll('```', '').trim();
      final rows = <_Row>[];
      for (final e in (jsonDecode(raw) as List)) {
        final name = '${e['product']}';
        final q = (e['quantity'] as num?)?.toDouble();
        final type = _typeNames.containsKey(e['type']) ? e['type'] as String : 'sale';
        final p = products.where((x) => x.label == name).firstOrNull ?? matchProduct(name, products);
        if (p != null && q != null) rows.add(_Row(p, q, type));
      }
      setState(() {
        _rows = rows;
        _note = rows.isEmpty ? 'I couldn\'t read this page clearly. Add the lines by hand below.' : 'Check each line against your book before saving.';
      });
    } catch (_) {
      setState(() => _note = 'Automatic reading isn\'t available right now. Add the lines by hand below, with the photo beside you.');
    }
    if (mounted) setState(() => _reading = false);
  }

  Future<void> _confirm() async {
    final seconds = DateTime.now().difference(_started).inSeconds;
    final now = DateTime.now();
    final list = [for (final (i, r) in _rows.indexed) StockLog(product: r.product.id, at: now, type: r.type, quantity: r.quantity, method: 'photo', secondsTaken: i == 0 ? seconds : null)];
    await saveWithGlow(context, widget.repo.addLogs(list), 'Saved from your stock book.');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Snap your stock book')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (_bytes == null) ...[
                  const SizedBox(height: 200, child: Mascot(state: 'log')),
                  Text('Keep your book. Just show it to me.', textAlign: TextAlign.center, style: B.display(23)),
                  const SizedBox(height: 6),
                  Text('Hold the phone flat over today\'s page, in good light.', textAlign: TextAlign.center, style: B.body(15, color: B.mute)),
                  const SizedBox(height: 18),
                ] else
                  ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(_bytes!, height: 280, fit: BoxFit.cover)),
                const SizedBox(height: 12),
                if (_reading) ...[
                  const SizedBox(height: 180, child: FxView(kind: 'quantum', fallback: Center(child: CircularProgressIndicator()))),
                  Text('Reading your handwriting…', textAlign: TextAlign.center, style: B.body(15, color: B.mute)),
                ] else ...[
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: () => _take(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: Text(_bytes == null ? 'Take photo' : 'Retake'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: () => _take(ImageSource.gallery), child: const Text('From gallery'))),
                  ]),
                  if (_note != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_note!, textAlign: TextAlign.center, style: B.body(14, color: B.gold, w: FontWeight.w600))),
                  if (_bytes != null) ...[
                    const SizedBox(height: 12),
                    _ConfirmList(rows: _rows, products: widget.repo.products, onChanged: () => setState(() {})),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add a line'),
                      onPressed: widget.repo.products.isEmpty ? null : () => setState(() => _rows.add(_Row(widget.repo.products.first, 1, 'sale'))),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _rows.isEmpty ? null : _confirm, child: const Text('Yes, save it')),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
}
