import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';

/// The sprout mark that sits beside the wordmark.
class LeafMark extends StatelessWidget {
  const LeafMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LeafPainter(k.colors.accent, k.colors.primary),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.light, this.dark);

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Stem.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.92)
        ..quadraticBezierTo(w * 0.46, h * 0.60, w * 0.52, h * 0.34),
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round,
    );

    // Left leaf.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50, h * 0.52)
        ..quadraticBezierTo(w * 0.10, h * 0.50, w * 0.14, h * 0.16)
        ..quadraticBezierTo(w * 0.46, h * 0.18, w * 0.50, h * 0.52)
        ..close(),
      Paint()..color = light,
    );

    // Right leaf, slightly higher.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.52, h * 0.44)
        ..quadraticBezierTo(w * 0.92, h * 0.40, w * 0.90, h * 0.06)
        ..quadraticBezierTo(w * 0.56, h * 0.10, w * 0.52, h * 0.44)
        ..close(),
      Paint()..color = dark,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}

/// Wordmark + tagline, with optional trailing actions. Appears at the top of
/// every tab.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.actions = const [], this.dense = false});

  final List<Widget> actions;

  /// Drops the tagline and tightens the wordmark. Used on Home, where vertical
  /// space is needed for the habit list and the tagline is repeated elsewhere.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LeafMark(size: dense ? 25 : 30),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppContent.appName,
                style: dense
                    ? k.text.wordmark.copyWith(fontSize: 21)
                    : k.text.wordmark,
              ),
              if (!dense) Text(AppContent.tagline, style: k.text.tagline),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// A screen's own header: its title on the left, actions on the right.
///
/// Inner screens deliberately do not repeat the "RewireMind" wordmark — the user
/// knows which app they are in, and the page title is the more useful anchor.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.titleSize = 25,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: k.text.pageTitle.copyWith(fontSize: titleSize),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: k.text.pageSubtitle.copyWith(fontSize: 11.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        ...actions,
      ],
    );
  }
}

/// Small circular avatar showing the user's initial.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initial,
    this.size = 38,
    this.onTap,
  });

  final String initial;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: k.colors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: k.text.cardTitle.copyWith(
            color: k.colors.primary,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}

/// Circular icon button used for the bell / settings / calendar actions.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.showBadge = false,
    this.size = 38,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showBadge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: k.colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: k.colors.outline),
              ),
              child: Icon(icon, color: k.colors.primary, size: size * 0.5),
            ),
            if (showBadge)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: k.colors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: k.colors.surface, width: 1.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
