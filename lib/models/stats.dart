import 'package:flutter/foundation.dart';

import 'habit.dart';
import 'progress_range.dart';

/// How a single day is rendered on the Calendar grid.
enum DayStatus {
  /// Every scheduled habit was completed.
  all,

  /// Some but not all.
  some,

  /// Scheduled habits, none completed.
  none,

  /// Nothing was scheduled (or the day predates every habit).
  empty,

  /// Later than today.
  future,
}

/// One bar/point on a Progress chart.
@immutable
class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.percent,
    this.sublabel,
    this.isCurrent = false,
    this.isFuture = false,
  });

  /// "Mon", "Week 1", "Jan", "2026".
  final String label;

  /// Secondary line under the label — "1 Sep", "1 – 7 Sep".
  final String? sublabel;

  final int percent;

  /// The bar for today / this week / this month, drawn in the deeper green.
  final bool isCurrent;

  /// Hasn't happened yet — drawn empty.
  final bool isFuture;
}

/// One row of the "Habit Breakdown" table.
@immutable
class HabitBreakdown {
  const HabitBreakdown({
    required this.habit,
    required this.completed,
    required this.scheduled,
    required this.streak,
  });

  final Habit habit;
  final int completed;
  final int scheduled;

  /// The habit's own current streak, shown on the weekly view.
  final int streak;

  int get percent =>
      scheduled == 0 ? 0 : ((completed / scheduled) * 100).round();
}

/// Everything the Progress tab needs for one range.
@immutable
class RangeStats {
  const RangeStats({
    required this.range,
    required this.completed,
    required this.scheduled,
    required this.previousPercent,
    required this.hasPrevious,
    required this.currentStreak,
    required this.bestStreak,
    required this.activeHabits,
    required this.totalHabits,
    required this.daysActive,
    required this.perfectDays,
    required this.series,
    required this.breakdown,
  });

  final ProgressRange range;

  /// Completed and scheduled slots in this range, counted up to today only —
  /// future days in the current week/month don't drag the percentage down.
  final int completed;
  final int scheduled;

  /// Completion rate over the equivalent previous period.
  final int previousPercent;

  /// False during a user's first week, month or year, when there is no earlier
  /// period to have done better or worse than.
  final bool hasPrevious;

  final int currentStreak;
  final int bestStreak;
  final int activeHabits;
  final int totalHabits;
  final int daysActive;

  /// Days in this range where every scheduled habit was completed.
  final int perfectDays;

  final List<ChartPoint> series;
  final List<HabitBreakdown> breakdown;

  int get percent =>
      scheduled == 0 ? 0 : ((completed / scheduled) * 100).round();

  /// Percentage-point change against the previous period.
  int get delta => percent - previousPercent;

  bool get hasComparison => range != ProgressRange.allTime;
}
