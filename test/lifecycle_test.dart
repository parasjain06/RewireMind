import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/models/progress_range.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Discontinuing a habit must not rewrite the past: the days it was actually
/// running still count, and only days after it stopped are excluded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a discontinued habit stops being scheduled from today', () async {
    final state = await seededState();
    final habit = state.habits.firstWhere((h) => h.id == 'habit_water');
    final yesterday = state.today.subtract(const Duration(days: 1));

    expect(state.scheduledOn(state.today).contains(habit), isTrue);

    await state.archiveHabit(habit);
    final stopped = state.everyHabit.firstWhere((h) => h.id == habit.id);

    expect(stopped.isArchived, isTrue);
    expect(
      state.habits.any((h) => h.id == habit.id),
      isFalse,
      reason: 'no longer an ongoing habit',
    );
    // Archived today, so today still counts; tomorrow will not.
    expect(
      state.scheduledOn(yesterday).any((h) => h.id == habit.id),
      isTrue,
      reason: 'it was running yesterday',
    );
    expect(
      state
          .scheduledOn(state.today.add(const Duration(days: 1)))
          .any((h) => h.id == habit.id),
      isFalse,
      reason: 'not scheduled after it stopped',
    );
  });

  test('past statistics are unchanged by discontinuing', () async {
    final state = await seededState();
    final habit = state.habits.firstWhere((h) => h.id == 'habit_water');

    // Last week is entirely in the past, so it must be unaffected.
    final lastWeekStart = startOfWeek(state.today)
        .subtract(const Duration(days: 7));
    final lastWeekEnd = lastWeekStart.add(const Duration(days: 6));
    final before = state.habitTally(habit, lastWeekStart, lastWeekEnd);

    await state.archiveHabit(habit);
    final stopped = state.everyHabit.firstWhere((h) => h.id == habit.id);
    final after = state.habitTally(stopped, lastWeekStart, lastWeekEnd);

    expect(after.completed, before.completed);
    expect(after.scheduled, before.scheduled);
  });

  test(
    'deleting still erases history, which is why archiving is preferred',
    () async {
      final state = await seededState();
      final habit = state.habits.firstWhere((h) => h.id == 'habit_water');
      final lastWeekStart = startOfWeek(state.today)
          .subtract(const Duration(days: 7));
      final before = state.habitTally(
        habit,
        lastWeekStart,
        lastWeekStart.add(const Duration(days: 6)),
      );
      expect(before.scheduled, greaterThan(0));

      await state.deleteHabit(habit);
      expect(state.everyHabit.any((h) => h.id == habit.id), isFalse);
    },
  );

  test('a habit stopped mid-week still counts for the days it ran', () async {
    final state = await seededState();
    final habit = state.habits.first;

    // Stop it as of two days ago.
    final stopDay = state.today.subtract(const Duration(days: 2));
    await state.updateHabit(habit.copyWith(archivedAt: stopDay));
    final stopped = state.everyHabit.firstWhere((h) => h.id == habit.id);

    expect(stopped.isActiveOnDay(stopDay), isTrue, reason: 'its last day');
    expect(
      stopped.isActiveOnDay(stopDay.add(const Duration(days: 1))),
      isFalse,
      reason: 'the day after it stopped',
    );
    expect(
      stopped.isActiveOnDay(stopDay.subtract(const Duration(days: 1))),
      isTrue,
      reason: 'while it was still running',
    );
  });

  test('discontinued habits still appear in ranges they overlap', () async {
    final state = await seededState();
    final habit = state.habits.first;
    await state.archiveHabit(habit);

    final week = state.boundsFor(ProgressRange.week);
    final rows = state.habitsInRange(week.start, week.end);
    expect(
      rows.any((h) => h.id == habit.id),
      isTrue,
      reason: 'it ran during this week, so it belongs in the breakdown',
    );

    // A window entirely after it stopped should not list it.
    final future = state.today.add(const Duration(days: 30));
    final later = state.habitsInRange(
      future,
      future.add(const Duration(days: 6)),
    );
    expect(later.any((h) => h.id == habit.id), isFalse);
  });

  test('restoring resumes tracking', () async {
    final state = await seededState();
    final habit = state.habits.first;

    await state.archiveHabit(habit);
    expect(state.habits.any((h) => h.id == habit.id), isFalse);

    await state.restoreHabit(
      state.everyHabit.firstWhere((h) => h.id == habit.id),
    );
    expect(state.habits.any((h) => h.id == habit.id), isTrue);
    expect(
      state.everyHabit.firstWhere((h) => h.id == habit.id).isArchived,
      isFalse,
    );
  });

  test('archiving survives a reload', () async {
    final state = await seededState();
    await state.archiveHabit(state.habits.first);

    final reloaded = await reopen();
    // The seed already contains one discontinued habit, so archiving another
    // makes two.
    expect(reloaded.everyHabit.where((h) => h.isArchived), hasLength(2));
    expect(reloaded.habits, hasLength(5));
  });

  group('habit kinds', () {
    test('a cut-back habit is a single daily tick', () async {
      final state = await seededState();
      final habit = await state.addHabit(
        name: 'Smoke less',
        iconKey: 'smoking',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      );

      expect(habit.kind, HabitKind.quit);
      expect(habit.isBinary, isTrue);
      expect(state.isComplete(habit, state.today), isFalse);

      await state.toggleComplete(habit, state.today);
      expect(state.isComplete(habit, state.today), isTrue);
    });

    test('kind survives a reload', () async {
      final state = await seededState();
      await state.addHabit(
        name: 'Less coffee',
        iconKey: 'caffeine',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      );

      final reloaded = await reopen();
      final restored = reloaded.habits.firstWhere(
        (h) => h.name == 'Less coffee',
      );
      expect(restored.kind, HabitKind.quit);
    });

    test('cut-back habits count toward completion like any other', () async {
      final state = await seededState();
      final habit = await state.addHabit(
        name: 'Less scrolling',
        iconKey: 'social',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      );

      final before = state.completedCountOn(state.today);
      await state.toggleComplete(habit, state.today);
      expect(state.completedCountOn(state.today), before + 1);
    });
  });

  group('perfect days', () {
    test('a day counts only when every scheduled habit is done', () async {
      final state = await seededState();
      final day = state.today.subtract(const Duration(days: 3));
      final scheduled = state.scheduledOn(day);
      expect(scheduled, isNotEmpty);

      // Clear the day, then complete all but one.
      for (final habit in scheduled) {
        await state.setValue(habit, day, 0);
      }
      expect(state.isPerfectDay(day), isFalse);

      for (final habit in scheduled.take(scheduled.length - 1)) {
        await state.setValue(habit, day, habit.target);
      }
      expect(
        state.isPerfectDay(day),
        isFalse,
        reason: 'one habit still outstanding',
      );

      await state.setValue(scheduled.last, day, scheduled.last.target);
      expect(state.isPerfectDay(day), isTrue);
    });

    test('a day with nothing scheduled is not perfect', () async {
      final state = await emptyState();
      expect(
        state.isPerfectDay(state.today),
        isFalse,
        reason: 'empty is not the same as perfect',
      );
      expect(state.perfectDays, 0);
    });

    test('future days are never perfect', () async {
      final state = await seededState();
      final tomorrow = state.today.add(const Duration(days: 1));
      expect(state.isPerfectDay(tomorrow), isFalse);
    });

    test('completing today raises the count by one', () async {
      final state = await seededState();
      final before = state.perfectDays;
      expect(state.isPerfectDay(state.today), isFalse);

      for (final habit in state.scheduledOn(state.today)) {
        await state.setValue(habit, state.today, habit.target);
      }

      expect(state.isPerfectDay(state.today), isTrue);
      expect(state.perfectDays, before + 1);
    });

    test('the range tally matches a manual count', () async {
      final state = await seededState();
      final week = state.boundsFor(ProgressRange.week);

      var manual = 0;
      for (
        var d = week.start;
        !d.isAfter(state.today);
        d = d.add(const Duration(days: 1))
      ) {
        if (state.isPerfectDay(d)) manual++;
      }

      expect(state.statsFor(ProgressRange.week).perfectDays, manual);
    });
  });

  group('future days', () {
    test('cannot be marked done through any route', () async {
      final state = await seededState();
      final habit = state.habits.first;
      final tomorrow = state.today.add(const Duration(days: 1));
      final nextWeek = state.today.add(const Duration(days: 7));

      // toggleComplete, setValue and adjustValue all funnel through setValue,
      // so guarding there covers Home, the calendar sheet, the week table and
      // the detail screen at once.
      await state.toggleComplete(habit, tomorrow);
      expect(state.isComplete(habit, tomorrow), isFalse);
      expect(state.valueOf(habit.id, tomorrow), 0);

      await state.setValue(habit, nextWeek, habit.target);
      expect(state.valueOf(habit.id, nextWeek), 0);

      await state.adjustValue(habit, tomorrow, habit.target);
      expect(state.valueOf(habit.id, tomorrow), 0);
    });

    test('today and the past are still writable', () async {
      final state = await seededState();
      final habit = state.habits.first;
      final yesterday = state.today.subtract(const Duration(days: 1));

      await state.setValue(habit, state.today, habit.target);
      expect(state.isComplete(habit, state.today), isTrue);

      await state.setValue(habit, yesterday, habit.target);
      expect(state.isComplete(habit, yesterday), isTrue);
    });

    test('a future day never counts as scheduled work', () async {
      final state = await seededState();
      final tomorrow = state.today.add(const Duration(days: 1));
      final before = state.statsFor(ProgressRange.week).scheduled;

      for (final habit in state.habits) {
        await state.toggleComplete(habit, tomorrow);
      }

      expect(state.completedCountOn(tomorrow), 0);
      expect(
        state.statsFor(ProgressRange.week).scheduled,
        before,
        reason: 'tomorrow must not enter the tally',
      );
    });
  });

  test('a day key round-trips', () {
    final d = DateTime(2026, 9, 4, 17, 30);
    expect(dayFromKey(dayKey(d)), dateOnly(d));
  });
}
