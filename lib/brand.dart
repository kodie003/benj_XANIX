import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The benj green, taken from the logo. Also seeds the app's colour scheme.
const benjGreen = Color(0xFF1B7A3D);

/// The full benj logo (tile + wordmark). Size it by height; width follows.
class BenjLogo extends StatelessWidget {
  const BenjLogo({super.key, this.height = 28});
  final double height;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/brand/logo.svg', height: height, semanticsLabel: 'benj');
}

/// Just the b tile, for tight spaces and the loading screen.
class BenjMark extends StatelessWidget {
  const BenjMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/brand/mark.svg', height: size, width: size, semanticsLabel: 'benj');
}

/// Shown while Firebase checks who is signed in, or a shop is loading.
class BenjLoading extends StatelessWidget {
  const BenjLoading({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BenjMark(size: 72),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ]),
        ),
      );
}
