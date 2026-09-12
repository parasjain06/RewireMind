import 'package:flutter/foundation.dart';

import '../content/reminder_library.dart';
import 'reminder.dart';

/// The whole notification setup: a master switch and the user's own list.
///
/// There is deliberately nothing else here — no app-chosen schedule, no
/// built-in categories. What is said, when, and how often is entirely the
/// contents of [reminders].
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = false,
    this.reminders = const [],
    this.catchUpEnabled = true,
    this.catchUpTime = const TimeOfDayValue(20, 30),
    this.appendQuote = false,
    this.habitRemindersEnabled = true,
    this.generalEnabled = false,
    this.challengeEnabled = true,
  });

  /// The 21-day challenge's nudge. It shares the catch-up's slot rather than
  /// taking one of its own: an unlogged day and a challenge day at risk are
  /// the same fact, so while the challenge runs the one evening send talks
  /// about it, and there is never a second.
  final bool challengeEnabled;

  /// Whether the one evening send is on at all, for either reason.
  bool get nudgeEnabled => catchUpEnabled || challengeEnabled;

  /// The two kinds of reminder the user writes, switched as a group: those
  /// tied to a habit, and the general ones. Turning a kind off keeps its
  /// reminders — they come back as they were when it is turned on again.
  ///
  /// General reminders start off. They are the ones not tied to anything,
  /// and a first evening with three notifications in it was two too many.
  final bool habitRemindersEnabled;
  final bool generalEnabled;

  /// Master switch. Off until the user turns it on and grants permission, so
  /// a fresh install is silent.
  final bool enabled;

  /// In display order — the settings list, and the order they were added.
  final List<Reminder> reminders;

  /// The one reminder the app words itself: "you have not logged today".
  ///
  /// Deliberately a single send rather than a pair. Not having logged today is
  /// the same fact as a streak being about to break, so two notifications
  /// would always fire together and say the same thing twice — only the
  /// wording changes, depending on whether a streak is actually on the line.
  final bool catchUpEnabled;
  final TimeOfDayValue catchUpTime;

  /// Whether the day's line is appended under every reminder.
  ///
  /// One switch rather than one per reminder. Asked five times it produced
  /// five different answers and a list where some reminders carried a quote
  /// and others did not for no reason anybody could remember — and there is
  /// only one quote a day, so five reminders would have repeated it anyway.
  final bool appendQuote;

  /// Reminders attached to one habit.
  List<Reminder> forHabit(String habitId) =>
      reminders.where((r) => r.habitId == habitId).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  /// Reminders not tied to any habit.
  List<Reminder> get general =>
      reminders.where((r) => !r.isForHabit).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  List<Reminder> get active => reminders
      .where((r) => r.enabled && kindEnabled(r))
      .toList(growable: false);

  /// Whether the kind this reminder belongs to is switched on.
  bool kindEnabled(Reminder r) =>
      r.isForHabit ? habitRemindersEnabled : generalEnabled;

  /// Reminders sorted by the hour they arrive, which is how the list reads
  /// best: a day from top to bottom.
  List<Reminder> get byTime {
    final sorted = reminders.toList()..sort((a, b) => a.time.compareTo(b.time));
    return sorted;
  }

  NotificationPrefs copyWith({
    bool? enabled,
    List<Reminder>? reminders,
    bool? catchUpEnabled,
    TimeOfDayValue? catchUpTime,
    bool? appendQuote,
    bool? habitRemindersEnabled,
    bool? generalEnabled,
    bool? challengeEnabled,
  }) => NotificationPrefs(
    enabled: enabled ?? this.enabled,
    reminders: reminders ?? this.reminders,
    catchUpEnabled: catchUpEnabled ?? this.catchUpEnabled,
    catchUpTime: catchUpTime ?? this.catchUpTime,
    appendQuote: appendQuote ?? this.appendQuote,
    habitRemindersEnabled: habitRemindersEnabled ?? this.habitRemindersEnabled,
    generalEnabled: generalEnabled ?? this.generalEnabled,
    challengeEnabled: challengeEnabled ?? this.challengeEnabled,
  );

  /// Drops every reminder belonging to a habit that no longer exists.
  NotificationPrefs removeForHabit(String habitId) => copyWith(
    reminders: reminders.where((r) => r.habitId != habitId).toList(),
  );

  NotificationPrefs upsert(Reminder reminder) {
    final next = reminders.toList();
    final at = next.indexWhere((r) => r.id == reminder.id);
    at == -1 ? next.add(reminder) : next[at] = reminder;
    return copyWith(reminders: next);
  }

  NotificationPrefs remove(String id) =>
      copyWith(reminders: reminders.where((r) => r.id != id).toList());

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'catchUpEnabled': catchUpEnabled,
    'catchUpTime': catchUpTime.toJson(),
    'appendQuote': appendQuote,
    'habitRemindersEnabled': habitRemindersEnabled,
    'generalEnabled': generalEnabled,
    'challengeEnabled': challengeEnabled,
  };

  static NotificationPrefs fromJson(Map<String, dynamic> json) {
    var reminders = [
      for (final raw in (json['reminders'] as List? ?? const []))
        Reminder.fromJson(raw as Map<String, dynamic>),
    ];
    var general = json['generalEnabled'] as bool? ?? false;

    // Saved before general reminders started off. Turning notifications on
    // used to add two of them by itself; the ones still exactly as they were
    // added go, and the kind is left on only if anything of yours is left in
    // it. Anything edited or written by hand stays.
    if (!json.containsKey('challengeEnabled')) {
      final starters = {for (final s in ReminderLibrary.starters) s.text};
      reminders = [
        for (final r in reminders)
          if (r.isForHabit || !starters.contains(r.text)) r,
      ];
      general = general && reminders.any((r) => !r.isForHabit);
    }

    return NotificationPrefs(
      enabled: json['enabled'] as bool? ?? false,
      reminders: reminders,
      challengeEnabled: json['challengeEnabled'] as bool? ?? true,
      catchUpEnabled: json['catchUpEnabled'] as bool? ?? true,
      appendQuote: json['appendQuote'] as bool? ?? false,
      habitRemindersEnabled: json['habitRemindersEnabled'] as bool? ?? true,
      generalEnabled: general,
      catchUpTime: json['catchUpTime'] == null
          ? const TimeOfDayValue(20, 30)
          : TimeOfDayValue.fromJson(
              json['catchUpTime'] as Map<String, dynamic>,
            ),
    );
  }
}
