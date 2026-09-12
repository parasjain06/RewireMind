import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White rounded card used throughout the app.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.soft = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Use the tinted surface instead of white (stat strips, banners).
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final decoration = soft ? k.softCardDecoration : k.cardDecoration;

    final content = Padding(
      padding: padding ?? EdgeInsets.all(k.geometry.cardPadding),
      child: child,
    );

    if (onTap == null && onLongPress == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return DecoratedBox(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
          child: content,
        ),
      ),
    );
  }
}

/// Round icon chip beside habits and profile rows.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.iconKey,
    required this.icon,
    this.size,
  });

  final String iconKey;
  final IconData icon;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final accent = k.colors.accentFor(iconKey);
    final dimension = size ?? k.geometry.iconChip;

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: accent.background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accent.foreground, size: dimension * 0.5),
    );
  }
}
