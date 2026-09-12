import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../models/journal_entry.dart';

/// How much one habit moves the mood.
@immutable
class HabitLift {
  const HabitLift({
    required this.habit,
    required this.delta,
    required this.withDays,
    required this.withoutDays,
  });

  final Habit habit;

  /// Average mood on days it was done, less the average on days it was due
  /// and not done. Positive lifts; negative weighs.
  final double delta;
  final int withDays;
  final int withoutDays;
}

/// The journal read back as patterns. Pure: no state, no clock of its own.
///
/// This is the part most journals leave out — entries go in and nothing
/// comes back. Here the habits already in the app are the other half of the
/// picture: a mood next to what you actually did that day is what turns a
/// diary into something you can act on.
abstract final class JournalInsights {
  /// Days needed on each side before a habit's lift is worth reporting. Two
  /// days either way is a coincidence, not a pattern.
  static const int minDays = 3;

  /// The mood of each day that has one: its latest entry with a mood.
  static Map<DateTime, int> dailyMood(List<JournalEntry> entries) {
    final latest = <DateTime, JournalEntry>{};
    for (final e in entries) {
      if (e.mood == null) continue;
      final seen = latest[e.day];
      if (seen == null || e.createdAt.isAfter(seen.createdAt)) {
        latest[e.day] = e;
      }
    }
    return {for (final e in latest.entries) e.key: e.value.mood!};
  }

  /// Every habit with enough days either way, biggest lift first.
  static List<HabitLift> lift({
    required Map<DateTime, int> moods,
    required List<Habit> habits,
    required bool Function(Habit habit, DateTime day) scheduled,
    required bool Function(Habit habit, DateTime day) done,
  }) {
    final out = <HabitLift>[];
    for (final habit in habits) {
      final withMood = <int>[];
      final withoutMood = <int>[];
      for (final e in moods.entries) {
        if (!scheduled(habit, e.key)) continue;
        (done(habit, e.key) ? withMood : withoutMood).add(e.value);
      }
      if (withMood.length < minDays || withoutMood.length < minDays) continue;
      double avg(List<int> v) => v.reduce((a, b) => a + b) / v.length;
      out.add(
        HabitLift(
          habit: habit,
          delta: avg(withMood) - avg(withoutMood),
          withDays: withMood.length,
          withoutDays: withoutMood.length,
        ),
      );
    }
    out.sort((a, b) => b.delta.compareTo(a.delta));
    return out;
  }

  /// The average mood of each of the [weeks] weeks up to [today], oldest
  /// first; null for a week with no moods in it.
  static List<double?> weekly(
    Map<DateTime, int> moods,
    DateTime today, {
    int weeks = 8,
  }) {
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    return [
      for (var w = weeks - 1; w >= 0; w--)
        () {
          final start = DateTime(monday.year, monday.month, monday.day - 7 * w);
          final values = [
            for (var d = 0; d < 7; d++)
              ?moods[DateTime(start.year, start.month, start.day + d)],
          ];
          return values.isEmpty
              ? null
              : values.reduce((a, b) => a + b) / values.length;
        }(),
    ];
  }

  /// Feelings by how often they come up, since [from].
  static List<(String, int)> feelings(
    List<JournalEntry> entries, {
    DateTime? from,
  }) {
    final counts = <String, int>{};
    for (final e in entries) {
      if (from != null && e.day.isBefore(from)) continue;
      for (final f in e.feelings) {
        counts[f] = (counts[f] ?? 0) + 1;
      }
    }
    final list = [for (final e in counts.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }
}
