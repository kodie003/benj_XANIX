import 'dart:convert';

import 'package:flutter/material.dart';

import 'fx_bridge_stub.dart' if (dart.library.js_interop) 'fx_bridge_web.dart' as bridge;

/// Tells a running effect what to do: FxController.send({'state': 'celebrate', 'ms': 1800}).
class FxController {
  void Function(String json)? _sender;
  final List<String> _queued = [];

  void send(Map<String, dynamic> msg) {
    final j = jsonEncode(msg);
    if (_sender != null) {
      _sender!(j);
    } else {
      _queued.add(j);
    }
  }

  void attach(void Function(String) s) {
    _sender = s;
    for (final j in _queued) {
      s(j);
    }
    _queued.clear();
  }

  void detach() => _sender = null;
}

/// Hosts one effect from web/fx. On platforms without WebGL it shows [fallback],
/// so the app is never blocked by graphics.
class FxView extends StatefulWidget {
  const FxView({super.key, required this.kind, this.config = const {}, this.controller, this.onEvent, this.fallback});
  final String kind;
  final Map<String, dynamic> config;
  final FxController? controller;
  final void Function(Map<String, dynamic>)? onEvent;
  final Widget? fallback;

  @override
  State<FxView> createState() => _FxViewState();
}

class _FxViewState extends State<FxView> {
  late final bridge.FxHost _host;
  bool _unsupported = !bridge.supported;

  @override
  void initState() {
    super.initState();
    _host = bridge.FxHost(widget.kind, jsonEncode(widget.config), (e) {
      final m = jsonDecode(e) as Map<String, dynamic>;
      if (m['name'] == 'nowebgl' && mounted) setState(() => _unsupported = true);
      widget.onEvent?.call(m);
    });
    widget.controller?.attach(_host.send);
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported) return widget.fallback ?? const SizedBox.shrink();
    return _host.build();
  }
}

/// Benj in a box, with a fallback picture for phones that can't run 3D.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.state = 'idle', this.framing = 'full', this.controller, this.onTap, this.turn = 0});
  final String state, framing;
  final FxController? controller;
  final VoidCallback? onTap;
  final double turn;

  @override
  Widget build(BuildContext context) => FxView(
        kind: 'mascot',
        config: {'state': state, 'framing': framing, 'turn': turn},
        controller: controller,
        fallback: Image.asset('assets/mascot_$framing.png', fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        onEvent: (e) {
          if (e['name'] == 'tap') onTap?.call();
        },
      );
}
