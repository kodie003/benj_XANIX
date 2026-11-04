import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repo.dart';
import '../core/theme.dart';
import '../fx/fx_view.dart';

const kDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// F1: shop details and consent. Products come next on the Log tab, so an owner
/// can be counting stock within a couple of minutes.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.repo, required this.user});
  final ShopRepo repo;
  final User user;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _location = TextEditingController();
  late final _phone = TextEditingController(text: widget.user.phoneNumber ?? '');
  int? _day;
  bool _consent = false;
  String? _error;

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Give your shop a name first.');
    if (!_consent) return setState(() => _error = 'Please tick the box so we can keep your records for you.');
    await widget.repo.saveShop(Shop(
      name: _name.text.trim(),
      ownerName: _owner.text.trim(),
      location: _location.text.trim(),
      ownerPhone: _phone.text.trim(),
      restockDay: _day,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const SizedBox(height: 170, child: Mascot(state: 'point')),
                  Text('Tell me about your shop', style: B.display(28)),
                  const SizedBox(height: 6),
                  Text('It takes a minute. I\'ll do the counting and warning from here.', style: B.body(15, color: B.mute)),
                  const SizedBox(height: 18),
                  TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Shop name')),
                  const SizedBox(height: 10),
                  TextField(controller: _owner, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Your name')),
                  const SizedBox(height: 10),
                  TextField(controller: _location, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Where is it?')),
                  const SizedBox(height: 10),
                  TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 18),
                  Text('Which day do you usually buy stock?', style: B.body(15, w: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < 7; i++)
                      ChoiceChip(
                        label: Text(kDays[i].substring(0, 3)),
                        selected: _day == i + 1,
                        selectedColor: B.gold,
                        labelStyle: B.body(14, w: FontWeight.w700, color: _day == i + 1 ? const Color(0xFF241600) : B.text),
                        onSelected: (_) => setState(() => _day = i + 1),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: B.gold,
                    value: _consent,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    title: Text('Keep my stock records so benj can warn me. They stay private to my account and aren\'t shared without my say.', style: B.body(14, color: B.mute)),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: B.body(14, color: B.coral, w: FontWeight.w600))),
                  FilledButton(onPressed: _start, child: const Text('Open my shop')),
                ],
              ),
            ),
          ),
        ),
      );
}
