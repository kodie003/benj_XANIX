import 'package:flutter/material.dart';

/// benj's look: night-market ink, marigold light and ledger lines from the stock books
/// we photographed. Colour always carries meaning: coral = running out, marigold = soon, teal = fine.
class B {
  static const ink = Color(0xFF080B18);
  static const surface = Color(0xFF12162C);
  static const raised = Color(0xFF1B2140);
  static const line = Color(0x24A9B6E8);
  static const text = Color(0xFFF3F5FF);
  static const mute = Color(0xFFA2ABCF);
  static const gold = Color(0xFFFFB627);
  static const teal = Color(0xFF2EE6C5);
  static const coral = Color(0xFFFF6257);
  static const violet = Color(0xFF8B7CFF);
  static const ledgerRed = Color(0xFFD8262F);

  static TextStyle display(double size, {FontWeight w = FontWeight.w700, Color color = text, double height = 1.05}) => TextStyle(
        fontFamily: 'Bricolage',
        fontSize: size,
        height: height,
        color: color,
        fontWeight: w,
        letterSpacing: -size * 0.02,
        fontVariations: [FontVariation('wght', w.value.toDouble()), const FontVariation('opsz', 40)],
      );
  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color color = text, double height = 1.35}) => TextStyle(
        fontFamily: 'Instrument',
        fontSize: size,
        height: height,
        color: color,
        fontWeight: w,
        fontVariations: [FontVariation('wght', w.value.toDouble())],
      );
  static TextStyle mono(double size, {FontWeight w = FontWeight.w500, Color color = mute, double spacing = 0.6}) => TextStyle(
        fontFamily: 'JetBrains',
        fontSize: size,
        color: color,
        fontWeight: w,
        letterSpacing: spacing,
        fontVariations: [FontVariation('wght', w.value.toDouble())],
      );

  static Color urgency(double? daysLeft, bool low) {
    if (daysLeft == null) return low ? coral : mute;
    if (low || daysLeft <= 2) return coral;
    if (daysLeft <= 5) return gold;
    return teal;
  }

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: ink,
      colorScheme: const ColorScheme.dark(primary: gold, onPrimary: Color(0xFF241600), secondary: teal, surface: surface, error: coral, onSurface: text),
      textTheme: base.textTheme.apply(fontFamily: 'Instrument', bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: display(20), foregroundColor: text),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF241600),
          minimumSize: const Size(64, 54),
          textStyle: body(16, w: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: text,
          side: const BorderSide(color: line),
          textStyle: body(15, w: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: body(14, color: mute),
        hintStyle: body(15, color: mute),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(backgroundColor: raised, contentTextStyle: body(14), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface, modalBackgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = B.surface, this.onTap, this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final Color? border;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: border ?? B.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = B.mute});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .35))),
        child: Text(text, style: B.body(12.5, w: FontWeight.w700, color: color)),
      );
}

/// Faint ledger grid: a nod to the stock books owners already keep.
class LedgerPainter extends CustomPainter {
  const LedgerPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0x0DA9B6E8);
    for (var y = 0.0; y < s.height; y += 28) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
    c.drawLine(const Offset(38, 0), Offset(38, s.height), Paint()..color = B.ledgerRed.withValues(alpha: .16));
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}
