import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/models/progress_range.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh install seeds its starter habits', () async {
    final state = await seededState();
    // Six ongoing (five to build, one to cut back) plus one already
    // discontinued, which exercises the archived treatment.
    expect(state.habits.length, 6);
    expect(state.everyHabit.length, 7);
    expect(state.everyHabit.where((h) => h.isArchived), hasLength(1));
    expect(state.habits.first.name, 'Drink 2L water');
  });

  test('toggling a habit updates completion and persists', () async {
    final state = await seededState();
    final habit = state.habits.firstWhere((h) => h.id == 'habit_water');
    final today = state.today;

    expect(state.isComplete(habit, today), isFalse);
    await state.toggleComplete(habit, today);
    expect(state.isComplete(habit, today), isTrue);

    // A second AppState reading the same store sees the change.
    final reloaded = await reopen();
    expect(reloaded.isComplete(habit, today), isTrue);
  });

  test('seeded history produces the intended streaks', () async {
    final state = await seededState();
    expect(state.currentStreak, 12);
    expect(state.bestStreak, 124);
  });

  test('every progress range reports a sane completion rate', () async {
    final state = await seededState();
    for (final range in ProgressRange.values) {
      final stats = state.statsFor(range);
      expect(
        stats.scheduled,
        greaterThan(0),
        reason: '${range.name} scheduled',
      );
      expect(stats.percent, inInclusiveRange(0, 100));
      expect(stats.completed, lessThanOrEqualTo(stats.scheduled));
      expect(stats.series, isNotEmpty, reason: '${range.name} series');
      expect(stats.breakdown, isNotEmpty, reason: '${range.name} breakdown');
    }
  });
}
