import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';
import 'completion_effects.dart';

/// "Start here", in handwriting, with an arrow swinging down to the plus.
///
/// Shown on Home while there is not a single habit, because an empty screen
/// with a button at the bottom of it does not say which button. It draws
/// itself in, nods a few times at the plus, and then keeps still — pointing,
/// not pestering.
///
/// Laid at the foot of the page, just above the navigation bar, and it
/// ignores touches: it points at the button, it never stands in front of it.
class PlusHint extends StatefulWidget {
  const PlusHint({super.key});

  /// How far the plus rises above the top of the navigation bar.
  static const double plusRise = 20;

  @override
  State<PlusHint> createState() => _PlusHintState();
}

class _PlusHintState extends State<PlusHint> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _nod = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _draw.value = 1;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _draw.forward();
      if (!mounted) return;
      await _nod.repeat(reverse: true, count: 6);
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    _nod.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ink = k.colors.script;

    return SizedBox(
      // Short enough that the words start below the empty card above them:
      // at 132 the hand-written line was crossing its bottom corner.
      height: 104,
      child: AnimatedBuilder(
        animation: Listenable.merge([_draw, _nod]),
        builder: (context, _) {
          final nod = Curves.easeInOut.transform(_nod.value) * 6;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HintArrow(
                    progress: Curves.easeOutCubic.transform(_draw.value),
                    nod: nod,
                    colour: ink,
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(-0.52, -0.88),
                child: Opacity(
                  opacity: (_draw.value * 3).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: -0.08,
                    child: Text(
                      AppContent.plusHint,
                      style: k.text.script.copyWith(fontSize: 30, color: ink),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A loose, swinging arrow from under the words to just above the plus.
class _HintArrow extends CustomPainter {
  _HintArrow({required this.progress, required this.nod, required this.colour});

  final double progress;
  final double nod;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final cx = size.width / 2;
    final start = Offset(cx - 58, 34);
    final end = Offset(cx - 4, size.height - PlusHint.plusRise - 14 + nod);

    // A pen stroke: out to the left, round, and down into the button.
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx - 44,
        start.dy + 34,
        end.dx - 50,
        end.dy - 10,
        end.dx,
        end.dy,
      );
    final metric = path.computeMetrics().first;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colour;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), pen);

    if (progress > 0.85) {
      final tip = metric.getTangentForOffset(metric.length);
      if (tip == null) return;
      final angle = math.atan2(tip.vector.dy, tip.vector.dx);
      final head = 12.0 * ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
      Offset wing(double turn) =>
          end - Offset(math.cos(angle + turn), math.sin(angle + turn)) * head;
      canvas.drawPath(
        Path()
          ..moveTo(wing(0.55).dx, wing(0.55).dy)
          ..lineTo(end.dx, end.dy)
          ..lineTo(wing(-0.55).dx, wing(-0.55).dy),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_HintArrow old) =>
      old.progress != progress || old.nod != nod || old.colour != colour;
}
