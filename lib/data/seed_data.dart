import 'dart:math';

import '../models/habit.dart';
import '../models/habit_log.dart';

/// ============================================================================
/// FIRST-RUN SEED
/// ============================================================================
/// The app is fully functional and persists real check-ins. This file only
/// decides what a *brand new* install starts with.
///
/// [seedDemoData] decides whether a fresh install is pre-populated with
/// example habits and ~2 years of generated history (handy for seeing the
/// Calendar and Progress screens with something in them), or starts completely
/// empty so you add your own and watch the app fill up.
///
/// The builders below always produce data; only [AppState.load] consults the
/// flag. That keeps them usable from tests regardless of how it is set.
/// ============================================================================

const bool seedDemoData = false;

/// Days of generated history when [seedDemoData] is on.
const int demoHistoryDays = 720;

/// The five habits from the approved mockups.
List<Habit> seedHabits(DateTime now) {
  final createdAt = now.subtract(const Duration(days: demoHistoryDays));
  return [
    Habit(
      id: 'habit_water',
      name: 'Drink 2L water',
      iconKey: 'water',
      target: 2,
      unit: 'L',
      createdAt: createdAt,
      sortOrder: 0,
    ),
    Habit(
      id: 'habit_read',
      name: 'Read 10 pages',
      iconKey: 'book',
      target: 10,
      unit: 'pages',
      createdAt: createdAt,
      sortOrder: 1,
    ),
    Habit(
      id: 'habit_exercise',
      name: 'Exercise 30 min',
      iconKey: 'exercise',
      target: 30,
      unit: 'min',
      createdAt: createdAt,
      sortOrder: 2,
    ),
    Habit(
      id: 'habit_meditate',
      name: 'Meditate 10 min',
      iconKey: 'meditate',
      target: 10,
      unit: 'min',
      createdAt: createdAt,
      sortOrder: 3,
    ),
    Habit(
      id: 'habit_sleep',
      name: 'Sleep before 11 PM',
      iconKey: 'sleep',
      target: 1,
      unit: 'time',
      createdAt: createdAt,
      sortOrder: 4,
    ),
    // A cut-back habit, so Home demonstrates the Build / Cut back split.
    Habit(
      id: 'habit_social',
      name: 'Less social media',
      iconKey: 'social',
      target: 1,
      unit: '',
      kind: HabitKind.quit,
      createdAt: now.subtract(const Duration(days: 210)),
      sortOrder: 5,
    ),
    // Tried for a few months, then stopped. Two years of real history would
    // contain one of these, and it exercises the discontinued treatment.
    Habit(
      id: 'habit_language',
      name: 'Learn Spanish',
      iconKey: 'study',
      target: 15,
      unit: 'min',
      createdAt: now.subtract(const Duration(days: 300)),
      archivedAt: now.subtract(const Duration(days: 96)),
      sortOrder: 6,
    ),
  ];
}

/// Target current/best streaks, so the generated history produces the kind of
/// numbers the Progress and Profile screens are designed around.
const int _targetCurrentStreak = 12;
const int _targetBestStreak = 124;

/// Builds `habitId -> { 'yyyy-MM-dd': value }` history.
///
/// Completion probability trends upward over time so the "improved from X% to
/// Y%" comparisons on Progress have something real to report.
Map<String, Map<String, double>> seedLogs(List<Habit> habits, DateTime now) {
  final rnd = Random(20260904);
  final today = dateOnly(now);
  const total = demoHistoryDays;

  // 1. Which days did the user show up at all? Streaks are built from these.
  final active = List<bool>.generate(total, (_) => rnd.nextDouble() > 0.06);

  // Current streak: the last N days active, the day before them missed.
  for (var i = total - _targetCurrentStreak; i < total; i++) {
    active[i] = true;
  }
  active[total - _targetCurrentStreak - 1] = false;

  // Best streak: one deliberately long run early on, fenced by missed days.
  const bestStart = 90;
  active[bestStart - 1] = false;
  for (var i = bestStart; i < bestStart + _targetBestStreak; i++) {
    active[i] = true;
  }
  active[bestStart + _targetBestStreak] = false;

  // Keep every other run shorter than the intended best streak.
  var runStart = 0;
  for (var i = 0; i <= total; i++) {
    final isActive = i < total && active[i];
    if (!isActive) {
      final runLength = i - runStart;
      if (runStart != bestStart && runLength >= _targetBestStreak) {
        active[runStart + runLength ~/ 2] = false;
      }
      runStart = i + 1;
    }
  }

  // 2. Per-habit completion on active days.
  const habitBias = {
    'habit_water': 0.06,
    'habit_read': -0.02,
    'habit_exercise': -0.14,
    'habit_meditate': 0.03,
    'habit_sleep': -0.07,
    'habit_social': -0.05,
    'habit_language': -0.18,
  };

  final logs = <String, Map<String, double>>{
    for (final h in habits) h.id: <String, double>{},
  };

  for (var i = 0; i < total; i++) {
    final day = today.subtract(Duration(days: total - 1 - i));
    if (!active[i]) continue;

    // Ramp from ~0.58 two years ago to ~0.82 today.
    final trend = 0.58 + 0.24 * (i / (total - 1));
    final weekendPenalty =
        (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday)
        ? 0.13
        : 0.0;

    var anyDone = false;
    for (final habit in habits) {
      if (!habit.isActiveOnDay(day)) continue;
      final p = (trend + (habitBias[habit.id] ?? 0) - weekendPenalty).clamp(
        0.05,
        0.95,
      );
      if (rnd.nextDouble() < p) {
        logs[habit.id]![dayKey(day)] = habit.target;
        anyDone = true;
      } else if (rnd.nextDouble() < 0.25) {
        // Partial progress — started but didn't finish.
        final fraction = 0.2 + rnd.nextDouble() * 0.5;
        final partial = (habit.target * fraction);
        if (partial >= 1 || habit.target < 2) {
          logs[habit.id]![dayKey(day)] = habit.target < 2
              ? 0
              : partial.floorToDouble();
        }
      }
    }

    // An "active" day must have at least one completion, or the streak maths
    // built above would not hold.
    if (!anyDone) {
      final scheduled = habits.where((h) => h.isActiveOnDay(day)).toList();
      if (scheduled.isNotEmpty) {
        final pick = scheduled[rnd.nextInt(scheduled.length)];
        logs[pick.id]![dayKey(day)] = pick.target;
      }
    }
  }

  // Today starts partly done, matching the Home mockup.
  final todayKey = dayKey(today);
  for (final habit in habits) {
    logs[habit.id]!.remove(todayKey);
  }
  logs['habit_read']?[todayKey] = 10;
  logs['habit_meditate']?[todayKey] = 10;

  return logs;
}
