import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/stats.dart';
import '../theme/app_theme.dart';

/// The filled / half / empty circle that summarises a day, used on the Home
/// week strip, the Calendar grid and its legend.
class DayStatusDot extends StatelessWidget {
  const DayStatusDot({
    super.key,
    required this.status,
    this.size = 16,
    this.onDark = false,
  });

  final DayStatus status;
  final double size;

  /// Rendered on the dark "today" pill, so it needs light colours.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    if (onDark) {
      return Container(
        width: size * 0.42,
        height: size * 0.42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    }

    switch (status) {
      case DayStatus.all:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: k.colors.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: size * 0.66, color: Colors.white),
        );
      case DayStatus.some:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _HalfDotPainter(k.colors.accent)),
        );
      case DayStatus.none:
      case DayStatus.empty:
      case DayStatus.future:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: k.colors.accentTrack, width: 1.6),
          ),
        );
    }
  }
}

/// Outlined circle with the left half filled — "some habits done".
class _HalfDotPainter extends CustomPainter {
  const _HalfDotPainter(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(0.9),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
    canvas.drawArc(
      rect.deflate(1.8),
      math.pi / 2,
      math.pi,
      true,
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_HalfDotPainter oldDelegate) => oldDelegate.fill != fill;
}
