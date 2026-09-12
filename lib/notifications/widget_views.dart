import 'dart:convert';

import '../models/habit_log.dart';
import '../models/stats.dart';

/// One habit on the checklist widget.
class WidgetTask {
  const WidgetTask(this.name, {this.done = false});

  final String name;
  final bool done;
}

/// What the checklist, week and month widgets read, written as JSON.
///
/// Pure, so the shape can be tested here rather than discovered on a phone.
/// The Kotlin side (RewireMindViewWidgets.kt) reads these back against the
/// real clock, which is why the checklist carries days ahead and the calendar
/// says which day it was written: a widget is looked at on days the app is
/// never opened.
abstract final class WidgetViews {
  /// How many days of checklist to write, today included.
  static const int listDays = 7;

  /// `{"habits": 1, "days": {"2026-09-11": [["Read", 1], ["Walk", 0]], ...}}`
  static String list({
    required Map<DateTime, List<WidgetTask>> days,
    required bool hasHabits,
  }) => jsonEncode({
    'habits': hasHabits ? 1 : 0,
    'days': {
      for (final entry in days.entries)
        dayKey(entry.key): [
          for (final task in entry.value) [task.name, task.done ? 1 : 0],
        ],
    },
  });

  /// `{"from": "2026-08-01", "stamp": "2026-09-11", "s": "aasn..."}`
  ///
  /// One letter per day from [from] to [stamp], the day it was written.
  static String calendar({
    required DateTime from,
    required DateTime stamp,
    required List<DayStatus> statuses,
  }) => jsonEncode({
    'from': dayKey(from),
    'stamp': dayKey(stamp),
    's': statuses.map(code).join(),
  });

  /// The letter for a day. Matches `Cal` in the Kotlin.
  static String code(DayStatus status) => switch (status) {
    DayStatus.all => 'a',
    DayStatus.some => 's',
    DayStatus.none => 'n',
    DayStatus.empty || DayStatus.future => 'e',
  };

  /// Where the calendar starts: the first of last month, so this week is
  /// whole even when it began in the month before.
  static DateTime calendarFrom(DateTime today) =>
      DateTime(today.year, today.month - 1, 1);
}
