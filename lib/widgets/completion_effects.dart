import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ============================================================================
/// THE COMPLETION MOMENT
/// ============================================================================
/// Ticking a habit is the most-repeated action in the app, so it is the one
/// worth making feel like something. These are the visual halves of that —
/// the haptics live at the call sites, because only they know whether a tap
/// finished the day.
///
/// Everything here is decorative and non-blocking: nothing waits on an
/// animation, nothing moves the layout, and all of it collapses to nothing
/// when the device asks for reduced motion.
/// ============================================================================

/// True when the platform has been asked to keep animation to a minimum.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ??
    MediaQuery.maybeOf(context)?.disableAnimations ??
    false;

/// A ring that expands and fades from where the finger was.
///
/// Grounds the day-closing moment at the circle that closed it, rather than
/// having something happen in a corner of the screen.
class RingPulse extends StatefulWidget {
  const RingPulse({super.key, required this.child, required this.play});

  final Widget child;

  /// Flipped to a new value to fire a pulse. Ignored when false.
  final bool play;

  @override
  State<RingPulse> createState() => _RingPulseState();
}

class _RingPulseState extends State<RingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void didUpdateWidget(RingPulse old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.isDismissed) return const SizedBox.shrink();
            final t = Curves.easeOutCubic.transform(_c.value);
            return IgnorePointer(
              child: Container(
                width: 30 + 46 * t,
                height: 30 + 46 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: k.colors.accent.withValues(alpha: (1 - t) * 0.55),
                    width: 2.4 * (1 - t) + 0.6,
                  ),
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

/// A scatter of leaves, drifting up and fading out.
///
/// Not confetti and not hearts: the app's mascot is a tree, so leaves are the
/// one thing here that could not have come from any other app.
class LeafBurst extends StatefulWidget {
  const LeafBurst({super.key, required this.play, this.count = 16});

  /// Flipped to a new value to fire the burst.
  final bool play;
  final int count;

  @override
  State<LeafBurst> createState() => _LeafBurstState();
}

class _LeafBurstState extends State<LeafBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  List<_Mote> _motes = const [];

  @override
  void didUpdateWidget(LeafBurst old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play && !reduceMotion(context)) {
      _motes = _Mote.scatter(widget.count);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isDismissed || _motes.isEmpty) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _LeafBurstPainter(
              motes: _motes,
              t: _c.value,
              tints: [
                k.colors.accent,
                k.colors.primary,
                Color.lerp(k.colors.accent, Colors.white, 0.35)!,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One drifting tick. Fixed at spawn so the scatter does not reshuffle on
/// every frame.
class _Mote {
  _Mote({
    required this.x,
    required this.drift,
    required this.rise,
    required this.size,
    required this.tilt,
    required this.tint,
    required this.delay,
  });

  final double x; // 0..1 across the width
  final double drift;
  final double rise;
  final double size;
  final double tilt;
  final int tint;
  final double delay;

  static List<_Mote> scatter(int count) {
    final rng = math.Random();
    return [
      for (var i = 0; i < count; i++)
        _Mote(
          x: 0.12 + rng.nextDouble() * 0.76,
          drift: (rng.nextDouble() - 0.5) * 46,
          rise: 90 + rng.nextDouble() * 70,
          size: 9 + rng.nextDouble() * 7,
          tilt: (rng.nextDouble() - 0.5) * 1.8,
          tint: rng.nextInt(3),
          delay: rng.nextDouble() * 0.22,
        ),
    ];
  }
}

class _LeafBurstPainter extends CustomPainter {
  _LeafBurstPainter({
    required this.motes,
    required this.t,
    required this.tints,
  });

  final List<_Mote> motes;
  final double t;
  final List<Color> tints;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in motes) {
      // Each tick starts a little after the one before, so the burst reads as
      // a scatter rather than a single block moving.
      final local = ((t - m.delay) / (1 - m.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final eased = Curves.easeOutCubic.transform(local);
      final fade = local < 0.25 ? local / 0.25 : 1 - ((local - 0.25) / 0.75);

      final cx = size.width * m.x + m.drift * eased;
      final cy = size.height - 18 - m.rise * eased;

      canvas.save();
      canvas.translate(cx, cy);
      // Keeps turning as it rises, the way a falling leaf does.
      canvas.rotate(m.tilt * (0.35 + eased * 1.4));

      final alpha = fade.clamp(0.0, 1.0);
      final s = m.size;

      // A leaf: two arcs meeting at a point, with a vein down the middle.
      // Drawn rather than laid out as an icon so it stays crisp this small.
      canvas.drawPath(
        Path()
          ..moveTo(0, -s)
          ..quadraticBezierTo(s * 0.82, -s * 0.1, 0, s)
          ..quadraticBezierTo(-s * 0.82, -s * 0.1, 0, -s),
        Paint()..color = tints[m.tint].withValues(alpha: alpha * 0.92),
      );
      canvas.drawLine(
        Offset(0, -s * 0.7),
        Offset(0, s * 0.72),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.35)
          ..strokeWidth = s * 0.11
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeafBurstPainter old) => old.t != t || old.motes != motes;
}
