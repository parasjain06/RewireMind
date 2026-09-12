import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A run of days that scrolls sideways under a heading that does not.
///
/// Both the board and the calendar's overview are the same shape — names held
/// down the left, days running off both edges — and they used to be two
/// different answers to it: one scrolled through ten weeks, the other sat on
/// one week you stepped with arrows. This is the board's answer, kept in one
/// place so the overview can hold it too.
///
/// The two scroll views are `reverse: true`, which puts the origin at the
/// right-hand end — so a strip opens on today without anybody jumping it
/// there. Jumping it in a post-frame callback measured the extent before the
/// rows had laid out and landed a week and a half short; starting at the end
/// is not a correction, it is where the viewport already is.
mixin DayStripScroll<T extends StatefulWidget> on State<T> {
  /// The one the finger drives.
  final ScrollController stripBody = ScrollController();

  /// The dates above it, driven by [stripBody] and not scrollable itself.
  ///
  /// One-way on purpose. Two controllers listening to each other is how you
  /// get a feedback loop that jitters; this one cannot be dragged, so there is
  /// only ever one source of truth for the offset.
  final ScrollController stripHead = ScrollController();

  /// Whether there are earlier days off the left edge, and later ones off the
  /// right. The strip is reversed, so earlier means further from offset zero.
  bool earlier = false;
  bool later = false;

  /// One day's width, as last laid out, so a tap on an arrow moves a week.
  /// Set by the view as it lays its days out.
  double dayWidth = 40;

  @override
  void initState() {
    super.initState();
    stripBody.addListener(_mirror);
    // The extents exist only after the first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mirror());
  }

  void _mirror() {
    if (!stripHead.hasClients || !stripBody.hasClients) return;
    final at = stripBody.offset.clamp(
      stripHead.position.minScrollExtent,
      stripHead.position.maxScrollExtent,
    );
    if (stripHead.offset != at) stripHead.jumpTo(at);

    final position = stripBody.position;
    final back = position.pixels < position.maxScrollExtent - 1;
    final forward = position.pixels > position.minScrollExtent + 1;
    if (back != earlier || forward != later) {
      setState(() {
        earlier = back;
        later = forward;
      });
    }
  }

  /// A week back (towards earlier days) or forward (towards today).
  void stepWeek({required bool back}) {
    if (!stripBody.hasClients) return;
    final position = stripBody.position;
    final target = (position.pixels + (back ? 7 : -7) * dayWidth).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    stripBody.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    stripBody.removeListener(_mirror);
    stripBody.dispose();
    stripHead.dispose();
    super.dispose();
  }
}

/// Fades a scrolling strip out at whichever ends have more beyond them, so
/// the days visibly carry on past the card's edge rather than stopping at it.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.left,
    required this.right,
    required this.child,
  });

  final bool left;
  final bool right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!left && !right) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: [
          left ? Colors.transparent : Colors.black,
          Colors.black,
          Colors.black,
          right ? Colors.transparent : Colors.black,
        ],
        stops: const [0.0, 0.1, 0.9, 1.0],
      ).createShader(rect),
      child: child,
    );
  }
}

/// The arrow beside a strip that has more days that way.
///
/// A strip that simply stops at the card's edge reads as all there is; this
/// says there is more, and which way.
class StepArrow extends StatelessWidget {
  const StepArrow({
    super.key,
    required this.back,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
  });

  final bool back;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Center(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: k.colors.surface,
          shape: CircleBorder(side: BorderSide(color: k.colors.outline)),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                back ? Icons.chevron_left : Icons.chevron_right,
                size: size,
                color: k.colors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
