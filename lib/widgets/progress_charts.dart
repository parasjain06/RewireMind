import 'package:flutter/material.dart';

import '../models/stats.dart';
import '../theme/app_theme.dart';

/// Circular completion ring with the percentage in the middle.
class PercentRing extends StatelessWidget {
  const PercentRing({
    super.key,
    required this.percent,
    this.size = 58,
    this.strokeWidth = 6,
  });

  final int percent;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              percent: percent,
              fill: k.colors.accent,
              track: k.colors.accentTrack,
              strokeWidth: strokeWidth,
            ),
          ),
          Text(
            '$percent%',
            style: k.text.statValue.copyWith(fontSize: size * 0.26),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.fill,
    required this.track,
    required this.strokeWidth,
  });

  final int percent;
  final Color fill;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(strokeWidth / 2);

    canvas.drawArc(
      rect,
      0,
      6.28318,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (percent > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.28318 * (percent / 100).clamp(0, 1),
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.fill != fill || old.track != track;
}

// ---------------------------------------------------------------------------

/// Vertical bar chart used by the week / month / year progress views.
///
/// Bar tint tracks the value, so a strong week reads darker at a glance.
class ProgressBarChart extends StatelessWidget {
  const ProgressBarChart({
    super.key,
    required this.points,
    this.height = 120,
    this.showAxis = false,
    this.dense = false,
  });

  final List<ChartPoint> points;
  final double height;

  /// Draws the 0% / 50% / 100% gridline labels (year view).
  final bool showAxis;

  /// Tighter typography for twelve-bar months.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final labelSize = dense ? 8.0 : 10.0;

    final chart = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final point in points)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: dense ? 1.5 : 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    point.isFuture ? '' : '${point.percent}%',
                    style: k.text.captionStrong.copyWith(fontSize: labelSize),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: height,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (point.percent / 100)
                            .clamp(0.012, 1)
                            .toDouble(),
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _barColor(k, point),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                              bottom: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    point.label,
                    textAlign: TextAlign.center,
                    style: k.text.captionStrong.copyWith(
                      fontSize: labelSize,
                      color: point.isCurrent
                          ? k.colors.primary
                          : k.colors.textSecondary,
                    ),
                    maxLines: 1,
                  ),
                  if (point.sublabel != null)
                    Text(
                      point.sublabel!,
                      textAlign: TextAlign.center,
                      style: k.text.caption.copyWith(fontSize: labelSize - 1),
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ),
      ],
    );

    if (!showAxis) return chart;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Nudge down past the value-label row so 100% lines up with the top
          // of the tallest possible bar.
          padding: EdgeInsets.only(top: labelSize + 6),
          child: SizedBox(
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final label in const ['100%', '50%', '0%'])
                  Text(label, style: k.text.caption.copyWith(fontSize: 8)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: chart),
      ],
    );
  }

  Color _barColor(RewireMindTheme k, ChartPoint point) {
    if (point.isFuture || point.percent == 0) return k.colors.accentTrack;
    final alpha = 0.30 + 0.65 * (point.percent / 100);
    return k.colors.accent.withValues(alpha: alpha.clamp(0.0, 1.0));
  }
}

// ---------------------------------------------------------------------------

/// Line chart used by the All Time view.
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({super.key, required this.points, this.height = 130});

  final List<ChartPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    if (points.isEmpty) return SizedBox(height: height);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final label in const ['100%', '50%', '0%'])
                Text(label, style: k.text.caption.copyWith(fontSize: 8)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LinePainter(
                    points: points,
                    line: k.colors.accent,
                    fill: k.colors.accent.withValues(alpha: 0.13),
                    grid: k.colors.outline,
                    badge: k.colors.primary,
                    badgeText: k.colors.surface,
                    surface: k.colors.surface,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final point in points)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            point.label,
                            textAlign: TextAlign.center,
                            style: k.text.captionStrong.copyWith(fontSize: 10),
                          ),
                          if (point.sublabel != null)
                            Text(
                              point.sublabel!,
                              textAlign: TextAlign.center,
                              style: k.text.caption.copyWith(fontSize: 8.5),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.line,
    required this.fill,
    required this.grid,
    required this.badge,
    required this.badgeText,
    required this.surface,
  });

  final List<ChartPoint> points;
  final Color line;
  final Color fill;
  final Color grid;
  final Color badge;
  final Color badgeText;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final step = points.length == 1 ? 0.0 : size.width / (points.length - 1);
    final coords = [
      for (var i = 0; i < points.length; i++)
        Offset(
          points.length == 1 ? size.width / 2 : step * i,
          size.height * (1 - (points[i].percent / 100).clamp(0, 1)),
        ),
    ];

    // Filled area under the line.
    final area = Path()..moveTo(coords.first.dx, size.height);
    for (final c in coords) {
      area.lineTo(c.dx, c.dy);
    }
    area
      ..lineTo(coords.last.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

    // The line itself.
    final stroke = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (final c in coords.skip(1)) {
      stroke.lineTo(c.dx, c.dy);
    }
    canvas.drawPath(
      stroke,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );

    // Markers.
    for (final c in coords) {
      canvas.drawCircle(c, 4.2, Paint()..color = surface);
      canvas.drawCircle(
        c,
        4.2,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    // Badge on the latest point.
    final last = coords.last;
    final text = TextPainter(
      text: TextSpan(
        text: '${points.last.percent}%',
        style: TextStyle(
          color: badgeText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          (last.dx - text.width / 2 - 6).clamp(
                0,
                size.width - text.width - 12,
              ) +
              text.width / 2 +
              6,
          (last.dy - 16).clamp(9.0, size.height),
        ),
        width: text.width + 12,
        height: 18,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(badgeRect, Paint()..color = badge);
    text.paint(
      canvas,
      Offset(
        badgeRect.center.dx - text.width / 2,
        badgeRect.center.dy - text.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}
