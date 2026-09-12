import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';
import 'completion_effects.dart';
import 'script_note.dart';

/// ============================================================================
/// THE DAY-COMPLETE MOMENT
/// ============================================================================
/// A full-screen beat when the last habit of the day is ticked: the screen
/// washes green, light fans out from behind a mark, and it
/// clears itself after a couple of seconds.
///
/// Shown through the app's [Overlay] rather than as a route, so it covers the
/// bottom bar as well as the page and cannot be reached by the back button —
/// it is a moment, not a screen you can navigate to.
/// ============================================================================

/// How long the whole thing lasts, entrance to exit.
const Duration _kTotal = Duration(milliseconds: 3450);
const Duration _kFade = Duration(milliseconds: 480);

/// Puts the celebration on screen. Returns as soon as it is scheduled — the
/// overlay removes itself.
void showDayComplete(BuildContext context, {required int streak}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // Nothing to celebrate with if the device has asked for stillness; the
  // haptic at the call site has already done its job.
  if (reduceMotion(context)) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => DayCompleteOverlay(
      streak: streak,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class DayCompleteOverlay extends StatefulWidget {
  const DayCompleteOverlay({
    super.key,
    required this.streak,
    required this.onDone,
  });

  final int streak;
  final VoidCallback onDone;

  @override
  State<DayCompleteOverlay> createState() => _DayCompleteOverlayState();
}

class _DayCompleteOverlayState extends State<DayCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _kTotal,
  )..forward();

  Timer? _exit;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _exit = Timer(_kTotal - _kFade, _dismiss);
  }

  /// Runs once, whether the timer or a tap gets there first.
  void _dismiss() {
    if (_leaving) return;
    _leaving = true;
    _exit?.cancel();
    setState(() {});
    Timer(_kFade, widget.onDone);
  }

  @override
  void dispose() {
    _exit?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    // The root overlay sits outside MaterialApp's Material, and text with no
    // Material ancestor renders with Flutter's debug yellow underline. This
    // is the whole reason for the wrapper.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedOpacity(
        opacity: _leaving ? 0 : 1,
        duration: _kFade,
        curve: Curves.easeOut,
        child: GestureDetector(
          // Tap to move on. Nothing here is worth making someone wait for.
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final wash = Curves.easeOutCubic.transform(
                (t / 0.14).clamp(0.0, 1.0),
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  // ---- the ground -------------------------------------------
                  Opacity(
                    opacity: wash,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.05,
                          colors: [k.colors.accent, k.colors.primary],
                        ),
                      ),
                    ),
                  ),

                  // ---- the light --------------------------------------------
                  CustomPaint(
                    painter: _RayPainter(t: t),
                    size: Size.infinite,
                  ),

                  // ---- the mark and the words -------------------------------
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Mark(t: t),
                        const SizedBox(height: 26),
                        _Words(t: t, streak: widget.streak),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The disc and its tick, arriving with a bounce.
class _Mark extends StatelessWidget {
  const _Mark({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    // Starts just after the wash, so the screen has turned green before the
    // mark lands on it.
    final local = ((t - 0.06) / 0.24).clamp(0.0, 1.0);
    final scale = 0.4 + 0.68 * Curves.easeOutBack.transform(local);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: local,
        child: Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.check_rounded, size: 62, color: k.colors.accent),
        ),
      ),
    );
  }
}

/// "Day closed" and what it earned.
///
/// The day streak, and deliberately not the challenge. This pill has now said
/// three different things: a perfect-day run, which collided with the weekly
/// "perfect" count on Home; then "Day 9 of 21", which dragged the challenge
/// into a moment that happens whether or not anybody has joined it. The flame
/// is the number already on Home, under the same name.
class _Words extends StatelessWidget {
  const _Words({required this.t, required this.streak});

  final double t;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final local = ((t - 0.14) / 0.22).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);

    return Opacity(
      opacity: local,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - eased)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The app's own handwriting, at a size it never gets elsewhere.
            ScriptNote(
              text: AppContent.homeDayClosed,
              align: TextAlign.center,
              fontSize: 44,
              underline: false,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(k.geometry.pillRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 7),
                  Text(
                    '$streak',
                    style: k.text.statValue.copyWith(
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    AppContent.homeStreakLabel,
                    style: k.text.caption.copyWith(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
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

// ---------------------------------------------------------------------------

/// Light fanning out from behind the mark, turning slowly.
///
/// There were paper frills thrown across this too — first as chips, then as
/// curled streamers — and neither read well: on a full green field they were
/// clutter over the one thing worth looking at. The rays alone are the
/// celebration.
class _RayPainter extends CustomPainter {
  _RayPainter({required this.t});

  final double t;

  static const int _rays = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.40);
    final reach = size.longestSide;

    // ---- rays -------------------------------------------------------------
    final rayIn = Curves.easeOut.transform((t / 0.22).clamp(0.0, 1.0));
    if (rayIn > 0) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      // Turns slowly throughout, which is what stops it looking like a decal.
      canvas.rotate(t * 0.55);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.085 * rayIn);
      const step = math.pi * 2 / _rays;

      for (var i = 0; i < _rays; i++) {
        final a = i * step;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a - 0.11) * reach, math.sin(a - 0.11) * reach)
            ..lineTo(math.cos(a + 0.11) * reach, math.sin(a + 0.11) * reach)
            ..close(),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RayPainter old) => old.t != t;
}
