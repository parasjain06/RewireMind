import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'completion_effects.dart';
import 'k_card.dart';
import 'challenge_guard.dart';

/// A habit with its progress for one day and a tap-to-complete control.
///
/// Shared by the Home list and the Calendar's day sheet so completing a habit
/// looks and behaves identically wherever you do it.
class HabitCheckRow extends StatelessWidget {
  const HabitCheckRow({
    super.key,
    required this.habit,
    required this.day,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
  });

  final Habit habit;
  final DateTime day;

  /// Opens the habit detail screen. Omit to render without a chevron.
  final VoidCallback? onTap;

  /// Opens the actions sheet — reorder, note, discontinue, delete.
  final VoidCallback? onLongPress;

  /// False for future days, which can't be checked off yet.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final complete = state.isComplete(habit, day);
    final value = state.valueOf(habit.id, day);
    final stopped = habit.isArchived;

    // A discontinued habit is shown, not hidden — its past still counts — but
    // it reads as retired: dimmed, struck through, and badged.
    return Opacity(
      opacity: stopped ? 0.62 : 1,
      child: KCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            IconChip(
              iconKey: habit.iconKey,
              icon: AppIcons.forKey(habit.iconKey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          habit.name,
                          style: k.text.cardTitle.copyWith(
                            decoration: stopped
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: k.colors.textMuted,
                            decorationThickness: 1.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (stopped) ...[
                        const SizedBox(width: 6),
                        _StoppedBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _statusLabel(complete, value),
                    style: k.text.caption.copyWith(
                      color: complete
                          ? k.colors.accent
                          : k.colors.textSecondary,
                      fontWeight: complete ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // The slot is always here, empty or not. Inserting it only when
            // a note existed shifted the tick circle left on those rows, so
            // the circles stopped lining up down the list.
            //
            // Drawn as a disc the same size as the tick beside it. A 15px
            // glyph floating next to a 27px circle read as a smudge rather
            // than as the pair they are.
            SizedBox(
              width: 33,
              child: state.hasNote(habit.id, day)
                  ? Center(
                      child: Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          color: k.colors.surfaceSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: k.colors.outline),
                        ),
                        child: Icon(
                          Icons.sticky_note_2_outlined,
                          size: 14,
                          color: k.colors.textSecondary,
                        ),
                      ),
                    )
                  : null,
            ),
            CheckButton(
              complete: complete,
              enabled: enabled,
              // Through the guard: a past challenge day asks first.
              onTap: () => editChallengeDay(
                context,
                day,
                () => context.read<AppState>().toggleComplete(habit, day),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: k.colors.textMuted),
            ],
          ],
        ),
      ),
    );
  }

  /// "Did it" and "avoided it" need different words for the same tick.
  ///
  /// Anything with a count keeps quoting the count when it is finished, so
  /// the line under the name always answers the same question — how much —
  /// and the tick, the colour and the weight answer whether that was enough.
  String _statusLabel(bool complete, double value) {
    if (habit.kind == HabitKind.quit) {
      return complete ? AppContent.quitDone : AppContent.quitPending;
    }
    if (!complete) return habit.progressLabel(value);
    return habit.isBinary ? AppContent.habitDone : habit.progressLabel(value);
  }
}

class _StoppedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
      ),
      child: Text(
        AppContent.discontinued,
        style: k.text.caption.copyWith(fontSize: 9, color: k.colors.textMuted),
      ),
    );
  }
}

/// The circular tick used to complete a habit.
/// The tick circle.
///
/// The single most-repeated control in the app, so it is worth more than a
/// colour swap: it compresses under the finger and overshoots on the way
/// back, and the check draws in just behind it. Undoing is deliberately
/// plain — if undo felt as good as completing, completing would stop meaning
/// anything.
class CheckButton extends StatefulWidget {
  const CheckButton({
    super.key,
    required this.complete,
    required this.onTap,
    this.enabled = true,
    this.size = 27,
  });

  final bool complete;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  State<CheckButton> createState() => _CheckButtonState();
}

class _CheckButtonState extends State<CheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  /// 1 → .86 → 1.14 → 1. The dip is the press, the overshoot is what makes it
  /// read as a button rather than a state change.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.86,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.86,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 34,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.14,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 38,
    ),
  ]).animate(_c);

  /// The check follows the fill rather than arriving with it.
  late final Animation<double> _mark = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.18, 1, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    // A habit that was already done when the row was built never animates, so
    // the controller has to start at the end — otherwise the check mark is
    // drawn at zero opacity and the circle reads as a blank green disc.
    if (widget.complete) _c.value = 1;
  }

  @override
  void didUpdateWidget(CheckButton old) {
    super.didUpdateWidget(old);
    // Only completing is celebrated, and only on the transition — not on
    // every rebuild that happens to arrive with `complete` already true.
    if (widget.complete && !old.complete) {
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    } else if (!widget.complete && old.complete) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    // Fired before anything is drawn: the haptic is what makes a tap feel
    // answered, and it arrives even when motion is switched off.
    if (!widget.complete) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final size = widget.size;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(
            scale: widget.complete ? _scale.value : 1,
            child: child,
          ),
          child: AnimatedContainer(
            duration: Duration(milliseconds: widget.complete ? 200 : 140),
            curve: widget.complete ? Curves.easeOut : Curves.linear,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: widget.complete ? k.colors.accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.complete ? k.colors.accent : k.colors.accentTrack,
                width: 1.8,
              ),
            ),
            child: widget.complete
                ? AnimatedBuilder(
                    animation: _mark,
                    builder: (context, _) {
                      final t = _mark.value.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: t,
                        child: Transform.rotate(
                          angle: (1 - t) * -0.32,
                          child: Transform.scale(
                            scale: 0.4 + 0.6 * t,
                            child: Icon(
                              Icons.check,
                              size: size * 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
