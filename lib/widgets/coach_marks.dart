import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';
import 'completion_effects.dart';

/// One stop on a tour of a screen: something on it to point at, and what to
/// say about it.
class CoachStep {
  const CoachStep({
    required this.target,
    required this.title,
    required this.body,
  });

  /// The widget being pointed at. A step whose target is not on screen is
  /// skipped rather than pointing at nothing.
  final GlobalKey target;
  final String title;
  final String body;
}

/// A tour of the screen underneath, one part at a time.
///
/// The part being explained is lit, everything else dimmed, and a hand-drawn
/// arrow runs from a short note to it — the way somebody would mark up a
/// screenshot for a friend. No card and no paragraph: a name in handwriting
/// and one line under it. Skip ends the whole thing from any step.
class CoachMarks {
  const CoachMarks._();

  /// Runs the tour and completes when it is finished or skipped.
  static Future<void> show(BuildContext context, List<CoachStep> steps) {
    final done = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        steps: steps,
        onDone: () {
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return done.future;
  }
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps, required this.onDone});

  final List<CoachStep> steps;
  final VoidCallback onDone;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// A soft dark halo under the note, so it reads over whatever is dimmed
  /// behind it.
  static const _lift = [
    Shadow(color: Color(0xCC000000), blurRadius: 12),
    Shadow(color: Color(0x99000000), blurRadius: 4),
  ];

  /// The ring round the lit part breathes, slowly, so the eye finds it.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// The steps whose targets are actually on screen, worked out once so the
  /// dots at the bottom do not change halfway through.
  late final List<CoachStep> _steps = [
    for (final step in widget.steps)
      if (_rectOf(step.target) != null) step,
  ];

  @override
  void initState() {
    super.initState();
    if (_steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _breathe();
    }
  }

  /// A few breaths on each step, then still: enough to catch the eye when
  /// the light moves, without pulsing on for as long as somebody reads.
  void _breathe() {
    if (reduceMotion(context)) return;
    _pulse
      ..value = 0
      ..repeat(reverse: true, count: 4);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Rect? _rectOf(GlobalKey key) {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    final rect = object.localToGlobal(Offset.zero) & object.size;
    // Built but scrolled out of sight is as good as missing: a light shone
    // on nothing, with an arrow pointing off the edge of the screen.
    // Read from the window rather than the widget tree: this runs while the
    // overlay is still being set up, before it may look anything up.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = view.physicalSize / view.devicePixelRatio;
    if (rect.bottom <= 60 || rect.top >= screen.height - 60) return null;
    return rect;
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      widget.onDone();
    } else {
      setState(() => _index++);
      _breathe();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) return const SizedBox.shrink();
    final k = context.k;
    final media = MediaQuery.of(context);
    final screen = media.size;
    final step = _steps[_index];
    final target = (_rectOf(step.target) ?? Rect.zero).inflate(8);
    final last = _index == _steps.length - 1;
    final calm = reduceMotion(context);

    // The note goes on whichever side has more room, and the buttons go to
    // the far edge on the other side, so neither covers what is being shown.
    final below = screen.height - target.bottom >= target.top;
    const gap = 92.0;
    final noteWidth = math.min(290.0, screen.width - 48);
    final noteLeft = (target.center.dx - noteWidth * 0.3).clamp(
      24.0,
      screen.width - 24 - noteWidth,
    );

    // The arrow: from just by the note to the edge of the lit part, leaning
    // towards the middle of the screen so it reads as a gesture, not a line.
    final endX = target.center.dx.clamp(target.left + 24, target.right - 24);
    final lean = endX < screen.width / 2 ? 34.0 : -34.0;
    final startX = (endX + lean).clamp(
      noteLeft + 18,
      noteLeft + noteWidth - 18,
    );
    final start = Offset(
      startX,
      below ? target.bottom + gap - 12 : target.top - gap + 12,
    );
    final end = Offset(endX, below ? target.bottom + 8 : target.top - 8);

    // A tap anywhere moves on — on the dimmed screen, on the lit part, on the
    // words. Only Skip, at the top, does anything else.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        key: const ValueKey('coachAdvance'),
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(
          children: [
            // The dimmed screen with the lit part cut out. It glides from one
            // part to the next rather than jumping, so the eye follows it.
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: target),
                  duration: Duration(milliseconds: calm ? 0 : 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, rect, _) => AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => CustomPaint(
                      painter: _ScrimPainter(
                        hole: rect ?? target,
                        colour: Colors.black.withValues(alpha: 0.84),
                        ring: Colors.white.withValues(
                          alpha: 0.35 + 0.35 * _pulse.value,
                        ),
                        spread: 2 + 3 * _pulse.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // The arrow, drawn on each time it moves to a new part.
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_index),
                  tween: Tween(begin: calm ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CustomPaint(
                    painter: _ArrowPainter(start: start, end: end, progress: t),
                  ),
                ),
              ),
            ),

            // The note: a name in handwriting and one line.
            Positioned(
              left: noteLeft,
              width: noteWidth,
              top: below ? target.bottom + gap : null,
              bottom: below ? null : screen.height - target.top + gap,
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: calm ? 0 : 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(0, below ? 0.12 : -0.12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_index),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      step.title,
                      style: k.text.script.copyWith(
                        fontSize: 34,
                        height: 1.0,
                        color: Colors.white,
                        shadows: _lift,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.body,
                      style: k.text.body.copyWith(
                        fontSize: 14.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: _lift,
                      ),
                    ),
                    // Said on the first step, where it is news, and the last,
                    // where tapping ends it. Not on every step in between.
                    if (_index == 0 || last) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              last
                                  ? AppContent.coachTapDone
                                  : AppContent.coachTapNext,
                              style: k.text.caption.copyWith(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Along the top, always in the same place: how far through, and
            // Skip — which ends the whole tour, from any step. Somebody who
            // wants out wants out. Nothing to skip on the last step.
            Positioned(
              left: 20,
              right: 12,
              top: media.padding.top + 10,
              child: Row(
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withValues(
                          alpha: i == _index ? 0.95 : 0.35,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(AppContent.coachSkip),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dimmed screen, with a rounded window cut out of it and a soft ring
/// round the window.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({
    required this.hole,
    required this.colour,
    required this.ring,
    required this.spread,
  });

  final Rect hole;
  final Color colour;
  final Color ring;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final window = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(window),
      ),
      Paint()..color = colour,
    );
    canvas.drawRRect(
      window.inflate(spread),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole ||
      old.colour != colour ||
      old.ring != ring ||
      old.spread != spread;
}

/// A hand-drawn arrow: a gentle curve with an open head, drawn from the note
/// to the lit part as [progress] runs from 0 to 1.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.start,
    required this.end,
    required this.progress,
  });

  final Offset start;
  final Offset end;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final dy = end.dy - start.dy;
    final dx = end.dx - start.dx;
    // Bowed out to one side, the way a pen swings, rather than ruled.
    final bow = dx.abs() < 8 ? 30.0 : -dx.sign * 22;
    final c1 = Offset(start.dx + bow, start.dy + dy * 0.45);
    final c2 = Offset(end.dx + bow * 0.4, end.dy - dy * 0.3);
    final curve = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    final metric = curve.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawPath(drawn, pen);

    // The head, once the line has arrived.
    if (progress > 0.82) {
      final tip = metric.getTangentForOffset(metric.length);
      if (tip == null) return;
      final angle = math.atan2(tip.vector.dy, tip.vector.dx);
      final head = 11.0 * ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
      Offset wing(double turn) =>
          end - Offset(math.cos(angle + turn), math.sin(angle + turn)) * head;
      canvas.drawPath(
        Path()
          ..moveTo(wing(0.5).dx, wing(0.5).dy)
          ..lineTo(end.dx, end.dy)
          ..lineTo(wing(-0.5).dx, wing(-0.5).dy),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.progress != progress || old.start != start || old.end != end;
}
