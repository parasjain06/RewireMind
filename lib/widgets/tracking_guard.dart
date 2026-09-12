import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_snackbar.dart';

/// Makes a change to [habit] on [day], asking first when the habit was not
/// being tracked then.
///
/// A value written against a day the habit was not running on is counted by
/// nothing: it stays out of the board, out of every streak and out of every
/// percentage, and it reappears only if you happen to open that same day
/// again. So either the day belongs to the habit — the habit started later
/// than you thought, and its start moves back — or the change does not
/// happen at all.
///
/// Three ways a day can be untracked, and they do not have the same answer:
///
///  * before the habit began — offered, because starting a habit today and
///    filling in the last few days is a thing people actually do;
///  * a weekday it does not run on — refused, with the way to its schedule,
///    since adding Sundays to fix one Sunday quietly marks every Sunday it
///    has ever had as missed;
///  * after it was discontinued — refused, because its history is closed.
/// What a day outside the habit's life or off its schedule is, in a line.
///
/// Both grids draw those days faintly rather than as misses; this is the same
/// fact in words, for a tap on one.
String untrackedNote(Habit habit, DateTime day) {
  final d = dateOnly(day);
  if (!habit.isWithinLifetime(d)) {
    final end = habit.endDay;
    return end != null && d.isAfter(end)
        ? AppContent.trackClosed(habit.name, DateFormat('d MMM').format(end))
        : AppContent.trackedFrom(
            habit.name,
            DateFormat('d MMM').format(habit.startDay),
          );
  }
  return AppContent.trackOffSchedule(habit.name, DateFormat('EEEE').format(d));
}

/// Says it, where there is a screen to say it on.
Future<void> showUntrackedNote(
  BuildContext context,
  Habit habit,
  DateTime day,
) => showAppSnackBar(context, message: untrackedNote(habit, day));

Future<void> editTrackedDay(
  BuildContext context,
  Habit habit,
  DateTime day,
  Future<void> Function() edit,
) async {
  final state = context.read<AppState>();
  final d = dateOnly(day);
  if (habit.isActiveOnDay(d)) {
    await edit();
    return;
  }

  final k = context.k;
  final when = DateFormat('EEE d MMM').format(d);

  // Not its weekday, or over: nothing to offer that does not rewrite more
  // than the day being looked at.
  if (!habit.isScheduledOn(d) ||
      (habit.endDay != null && d.isAfter(habit.endDay!))) {
    final closed = habit.endDay != null && d.isAfter(habit.endDay!);
    await showAppSnackBar(
      context,
      message: closed
          ? AppContent.trackClosed(
              habit.name,
              DateFormat('d MMM').format(habit.endDay!),
            )
          : AppContent.trackOffSchedule(
              habit.name,
              DateFormat('EEEE').format(d),
            ),
      duration: const Duration(seconds: 4),
    );
    return;
  }

  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: k.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
      ),
      icon: Icon(Icons.history_rounded, color: k.colors.primary, size: 30),
      title: Text(
        AppContent.trackEarlierTitle(when),
        style: k.text.cardTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        AppContent.trackEarlierBody(habit.name),
        style: k.text.body,
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            AppContent.trackEarlierNo,
            style: k.text.captionStrong.copyWith(color: k.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            AppContent.trackEarlierYes,
            style: k.text.captionStrong.copyWith(color: k.colors.primary),
          ),
        ),
      ],
    ),
  );
  if (go != true) return;

  await state.trackHabitFrom(habit, d);
  await edit();
  if (!context.mounted) return;
  await showAppSnackBar(
    context,
    message: AppContent.trackEarlierDone(habit.name, when),
  );
}
