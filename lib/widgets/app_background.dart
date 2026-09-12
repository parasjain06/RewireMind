import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The soft mint wash every screen sits on.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: k.colors.backgroundGradient,
          stops: k.colors.backgroundStops,
        ),
      ),
      child: child,
    );
  }
}
