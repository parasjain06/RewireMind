import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A short list of points, with a dot against each.
///
/// Used wherever a card used to carry a paragraph. Prose on a settings page is
/// read by nobody: it is skipped, and whatever it was explaining becomes a
/// surprise later. Three short lines get read, and they force the writing to
/// be specific — you cannot hedge in eight words.
class BulletList extends StatelessWidget {
  const BulletList({
    super.key,
    required this.points,
    this.tint,
    this.fontSize = 12,
  });

  final List<String> points;

  /// The dot's colour. Defaults to the accent; the danger cards pass their
  /// own so a warning does not have a cheerful green dot beside it.
  final Color? tint;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dot = tint ?? k.colors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: EdgeInsets.only(bottom: point == points.last ? 0 : 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  // Nudged down onto the first line's baseline rather than
                  // centred on a two-line point, which would float it.
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    point,
                    style: k.text.caption.copyWith(
                      fontSize: fontSize,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
