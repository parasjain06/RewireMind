import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// The 21-day path counts a *run* of perfect days, not a tally of them.
///
/// The distinction is the whole claim the challenge makes, and it is the one
/// thing about the path that cannot be seen by looking at it: a tally and a run
/// look identical right up until somebody misses a day.
void main() {
  /// One habit, completed on each of [on] days ago.
  Future<AppState> withDays(Set<int> on) async {
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
        createdAt: now.subtract(const Duration(days: 40)),
        sortOrder: 0,
      ),
    ]);
    await storage.saveLogs({
      'h': {
        for (final ago in on) dayKey(now.subtract(Duration(days: ago))): 1.0,
      },
    });
    await storage.markSeeded();

    final state = AppState(storage);
    await state.load();
    return state;
  }

  test('an unbroken run counts every day of it', () async {
    final state = await withDays({for (var i = 0; i < 9; i++) i});
    expect(state.perfectStreak, 9);
  });

  test('a missed day puts it back to nothing', () async {
    // Ten perfect days, then a gap four days ago.
    final state = await withDays({0, 1, 2, 3, 5, 6, 7, 8, 9, 10});
    expect(
      state.perfectStreak,
      4,
      reason: 'the run is only the days since the gap',
    );
    expect(
      state.perfectDays,
      10,
      reason: 'the tally still holds all ten — they are different questions',
    );
  });

  test('an unfinished today does not break the run', () async {
    // Yesterday back to five days ago, with today not done yet.
    final state = await withDays({1, 2, 3, 4, 5});
    expect(
      state.perfectStreak,
      5,
      reason:
          'until midnight the day is still winnable, so it is skipped '
          'rather than counted as a miss',
    );
  });

  test('nothing tracked is a run of nothing', () async {
    final state = await emptyState();
    expect(state.perfectStreak, 0);
  });

  test('finishing today extends the run to include it', () async {
    final state = await withDays({1, 2});
    expect(state.perfectStreak, 2);

    await state.toggleComplete(state.everyHabit.first, DateTime.now());
    expect(
      state.perfectStreak,
      3,
      reason:
          'the celebration reports this number, so it has to have moved '
          'by the time the day closes',
    );
  });
}
