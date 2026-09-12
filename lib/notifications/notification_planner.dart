import 'package:flutter/foundation.dart';

import '../content/notification_content.dart';
import '../models/day_phase.dart';
import '../models/habit.dart';
import '../models/notification_prefs.dart';

/// ============================================================================
/// THE PLANNER
/// ============================================================================
/// Turns the user's reminders into dated, fully worded notifications. It makes
/// no decisions about what to say or how often — that is the reminder list.
/// Its only judgements are mechanical: a time that has passed cannot be
/// scheduled, a day the reminder does not repeat on is skipped, and a reminder
/// marked "skip if the day is done" stays quiet on a finished day.
///
/// Pure by design: no plugin, no platform, no clock of its own, so all of it
/// is testable at any date and time we like.
/// ============================================================================

/// What a notification is, which decides its channel, its look and its
/// button.
enum SendKind {
  /// A reminder tied to one habit.
  habit,

  /// A reminder the user wrote, tied to nothing.
  general,

  /// The one evening send: the catch-up, or the challenge's day.
  nudge,
}

/// One notification, fully resolved and ready to hand to the platform.
@immutable
class PlannedSend {
  const PlannedSend({
    required this.reminderId,
    required this.at,
    required this.title,
    required this.body,
    required this.phase,
    this.kind = SendKind.general,
    this.habitId,
    this.canMarkDone = false,
    this.quickLabel,
    this.label,
    this.lines = const [],
    this.done = 0,
    this.total = 0,
  });

  final String reminderId;
  final DateTime at;

  /// Tokens already filled in — this is exactly what appears in the shade.
  final String title;
  final String body;

  /// Drives the notification's accent colour, so the shade matches the app the
  /// tap will open.
  final DayPhase phase;

  final SendKind kind;

  /// The habit a habit reminder is about.
  final String? habitId;

  /// Whether to offer the quick button: a habit reminder whose habit is still
  /// open.
  final bool canMarkDone;

  /// What that button says — "Mark done" on a daily tick, "+1 glass" on
  /// anything measured, so a reminder at two in the afternoon logs the glass
  /// you just drank rather than the whole day's eight.
  final String? quickLabel;

  /// The small line at the top, beside the app's name: the habit, or which
  /// evening send this is.
  final String? label;

  /// What is still to do, one per line, for the expanded evening send.
  final List<String> lines;

  /// Today so far, for the evening send's progress bar.
  final int done;
  final int total;

  /// Stable per reminder per day, so rescheduling replaces a pending
  /// notification rather than stacking a second copy beside it.
  int get id => Object.hash(reminderId, at.year, at.month, at.day) & 0x7fffffff;

  @override
  String toString() => '$reminderId@$at "$title"';
}

/// A day's worth of facts, gathered by the caller so the planner itself never
/// touches state.
@immutable
class DaySnapshot {
  const DaySnapshot({
    required this.day,
    required this.scheduled,
    required this.completed,
    required this.streak,
    this.name = 'you',
    this.challengeDay,
    this.challengeLength = 21,
  });

  /// Which day of the 21 this is, or null when no challenge is running on it.
  final int? challengeDay;
  final int challengeLength;

  final DateTime day;

  /// Habits actually on the schedule for this day, in display order.
  final List<Habit> scheduled;

  /// The subset already logged as complete.
  final Set<String> completed;

  final int streak;
  final String name;

  List<Habit> get pending =>
      scheduled.where((h) => !completed.contains(h.id)).toList();

  bool get isFullyLogged => scheduled.isNotEmpty && pending.isEmpty;

  Habit? habitById(String id) {
    for (final h in scheduled) {
      if (h.id == id) return h;
    }
    return null;
  }

  bool isDone(String habitId) => completed.contains(habitId);
}

class NotificationPlanner {
  const NotificationPlanner();

  /// Reserved id for the app-worded daily catch-up, so it can be told apart
  /// from the user's own reminders.
  static const String catchUpId = '_catchUp';

  /// Every send for [days] days starting at [from].
  ///
  /// [snapshotFor] is asked for one day at a time rather than being handed a
  /// list, because tomorrow's completions are unknowable and the caller
  /// decides how to project them.
  List<PlannedSend> plan({
    required NotificationPrefs prefs,
    required DateTime from,
    required int days,
    required DaySnapshot Function(DateTime day) snapshotFor,
  }) {
    if (!prefs.enabled) return const [];
    if (prefs.active.isEmpty && !prefs.nudgeEnabled) return const [];

    final sends = <PlannedSend>[];
    final start = DateTime(from.year, from.month, from.day);

    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      sends.addAll(
        planDay(prefs: prefs, snapshot: snapshotFor(day), now: from),
      );
    }

    sends.sort((a, b) => a.at.compareTo(b.at));
    return sends;
  }

  /// The rules, for a single day.
  @visibleForTesting
  List<PlannedSend> planDay({
    required NotificationPrefs prefs,
    required DaySnapshot snapshot,
    required DateTime now,
  }) {
    if (!prefs.enabled) return const [];

    // With nothing tracked there is no habit to name and nothing to chase, so
    // even a custom reminder would arrive talking about nothing.
    if (snapshot.scheduled.isEmpty) return const [];

    final sends = <PlannedSend>[];

    for (final reminder in prefs.reminders) {
      if (!reminder.firesOn(snapshot.day)) continue;
      // Its whole kind switched off on the Notifications page.
      if (!prefs.kindEnabled(reminder)) continue;

      // A habit-scoped reminder only concerns its own habit: it is silent on
      // days that habit is not scheduled, and — if asked to skip when done —
      // silent once that one habit is ticked, whatever the rest of the day
      // looks like.
      Habit? owner;
      if (reminder.isForHabit) {
        owner = snapshot.habitById(reminder.habitId!);
        if (owner == null) continue;
        if (reminder.skipWhenDone && snapshot.isDone(owner.id)) continue;
      } else if (reminder.skipWhenDone && snapshot.isFullyLogged) {
        continue;
      }

      final at = reminder.time.onDay(snapshot.day);
      if (!at.isAfter(now)) continue;

      sends.add(
        PlannedSend(
          reminderId: reminder.id,
          at: at,
          phase: DayPhase.of(at),
          title: reminder.text,
          // The quote is the only thing the app adds to a reminder, and only
          // when asked for it — once, in settings, rather than per reminder.
          body: prefs.appendQuote
              ? NotificationContent.quoteFor(snapshot.day)
              : '',
          kind: owner != null ? SendKind.habit : SendKind.general,
          habitId: owner?.id,
          label: owner?.name,
          // One habit, one tap — and only while it is still to do. There is
          // no button that ticks the whole day: one accidental tap on that
          // and a streak is a record of things that did not happen.
          canMarkDone: owner != null && !snapshot.isDone(owner.id),
          quickLabel: owner == null
              ? null
              : (owner.isBinary
                    ? NotificationContent.actionMarkDone
                    : NotificationContent.actionAdd(owner.stepLabel)),
        ),
      );
    }

    // ---- the evening nudge: catch-up or challenge ----------------------------
    //
    // One send, never two. An unlogged day, a streak about to break and a
    // challenge day at risk are all the same fact — nothing breaks until
    // midnight — so they share one slot and only the wording changes. While a
    // challenge is running and its nudge is on, it does the talking.
    final challenge = prefs.challengeEnabled ? snapshot.challengeDay : null;
    if ((prefs.catchUpEnabled || challenge != null) &&
        !snapshot.isFullyLogged) {
      final at = prefs.catchUpTime.onDay(snapshot.day);
      if (at.isAfter(now)) {
        final left = snapshot.pending;
        final first = left.isEmpty ? 'Your habits' : left.first.name;
        sends.add(
          PlannedSend(
            reminderId: catchUpId,
            at: at,
            phase: DayPhase.of(at),
            kind: SendKind.nudge,
            label: challenge != null
                ? NotificationContent.challengeLabel(
                    challenge,
                    snapshot.challengeLength,
                  )
                : NotificationContent.nudgeLabel,
            lines: [for (final h in left) h.name],
            done: snapshot.scheduled.length - left.length,
            total: snapshot.scheduled.length,
            title: challenge != null
                ? NotificationContent.challengeTitle(
                    challenge,
                    snapshot.challengeLength,
                  )
                : NotificationContent.catchUpTitle(
                    streak: snapshot.streak,
                    pending: left.length,
                  ),
            body: challenge != null
                ? NotificationContent.challengeBody(
                    pending: left.length,
                    firstPending: first,
                  )
                : NotificationContent.catchUpBody(
                    streak: snapshot.streak,
                    pending: left.length,
                    firstPending: first,
                    day: snapshot.day,
                  ),
          ),
        );
      }
    }

    return sends;
  }
}
