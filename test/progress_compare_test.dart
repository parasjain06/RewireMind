import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/models/progress_range.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Comparing a period against the one before it only means something when the
/// user was here for the one before it. Somebody three days in being told they
/// are up a hundred points on last week is being congratulated on nothing.
void main() {
  /// One habit created [ago] days back, completed every day since.
  Future<AppState> startedDaysAgo(int ago) async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    final now = dateOnly(DateTime.now());

    await storage.saveHabits([
      Habit(
        id: 'h',
        name: 'Walk',
        iconKey: 'walk',
        target: 1,
        unit: 'x',
        createdAt: now.subtract(Duration(days: ago)),
        sortOrder: 0,
      ),
    ]);
    await storage.saveLogs({
      'h': {
        for (var i = 0; i <= ago; i++)
          dayKey(now.subtract(Duration(days: i))): 1.0,
      },
    });
    await storage.markSeeded();

    final state = AppState(storage);
    await state.load();
    return state;
  }

  test('a first week has no previous week to beat', () async {
    final state = await startedDaysAgo(1);
    expect(state.statsFor(ProgressRange.week).hasPrevious, isFalse);
  });

  test('once a week has passed, the comparison is real', () async {
    final state = await startedDaysAgo(30);
    final week = state.statsFor(ProgressRange.week);
    expect(week.hasPrevious, isTrue);
    expect(week.previousPercent, greaterThan(0));
  });

  test('all time never compares — there is nothing before it', () async {
    final state = await startedDaysAgo(400);
    expect(state.statsFor(ProgressRange.allTime).hasPrevious, isFalse);
  });

  test('a tracked but failed period still counts as a comparison', () async {
    // Created a month ago, logged only today: last week existed and scored
    // zero, which is a real result rather than an absence of one.
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    final now = dateOnly(DateTime.now());
    await storage.saveHabits([
      Habit(
        id: 'h',
        name: 'Walk',
        iconKey: 'walk',
        target: 1,
        unit: 'x',
        createdAt: now.subtract(const Duration(days: 30)),
        sortOrder: 0,
      ),
    ]);
    await storage.saveLogs({
      'h': {dayKey(now): 1.0},
    });
    await storage.markSeeded();
    final state = AppState(storage);
    await state.load();

    final week = state.statsFor(ProgressRange.week);
    expect(week.hasPrevious, isTrue);
    expect(week.previousPercent, 0);
  });
}
