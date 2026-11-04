import 'package:flutter/material.dart';

import '../core/forecast.dart';
import '../core/models.dart';

/// Small shared helpers so every screen speaks the same plain English.

String qty(num v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

String cedis(num v) => 'GHS ${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(2)}';

/// "3 bags", "1 carton".
String units(Product p, num n) => '${qty(n)} ${p.plural(n)}';

/// "about 2 days left", "less than a day left", or null when we can't tell yet.
String? daysLeftText(Forecast f) {
  final d = f.daysLeft;
  if (f.stock <= 0) return 'sold out';
  if (d == null) return null;
  if (d < 1) return 'less than a day left';
  final n = d.floor();
  return 'about $n ${n == 1 ? 'day' : 'days'} left';
}

/// The plain-language buying line from PRD F5: "Buy 2 bags of Rice 4.5 kg".
String buyLine(Product p, int n) => 'Buy ${units(p, n)} of ${p.label}';

const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Urgency colours: red = running out, amber = soon, green = fine.
Color urgencyColor(BuildContext context, Forecast f) {
  if (f.isLow) return Theme.of(context).colorScheme.error;
  final d = f.daysLeft;
  if (d != null && d < f.leadDays + 3) return const Color(0xFFB26A00);
  return const Color(0xFF1B7A3D);
}

/// A titled section on a screen.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, this.trailing, required this.child});
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            ?trailing,
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

/// An empty state with one clear next step.
class Empty extends StatelessWidget {
  const Empty({super.key, required this.icon, required this.text, this.action, this.onAction});
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}
