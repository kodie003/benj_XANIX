import 'package:flutter/widgets.dart';

/// Poddy is drawn with WebGL, so builds other than the web show nothing for now.
class PoddyView extends StatelessWidget {
  const PoddyView({super.key, required this.mood, this.flash, this.flashTick = 0, this.onTap});

  final String mood;
  final String? flash;
  final int flashTick;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
