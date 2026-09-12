import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/screens/habit_detail_screen.dart';
import 'package:rewiremind/widgets/habit_row.dart';

import 'helpers.dart';

void main() {
  test('a part-done day counts for the part that was done', () async {
    final state = await emptyState();
    final habit = await state.addHabit(
      name: 'Read',
      iconKey: 'book',
      target: 10,
      unit: 'pages',
    );

    expect(state.habitDonePercent(habit), 0);
    await state.setValue(habit, state.today, 5);
    expect(
      state.habitDonePercent(habit),
      50,
      reason: 'five pages of ten is half a day, not a nought',
    );
    await state.setValue(habit, state.today, 10);
    expect(state.habitDonePercent(habit), 100);
  });

  test('starting a habit earlier brings that day into every count', () async {
    final state = await emptyState();
    final habit = await state.addHabit(
      name: 'Read',
      iconKey: 'book',
      target: 1,
      unit: '',
    );
    final yesterday = state.today.subtract(const Duration(days: 1));

    // Written against a day the habit was not running on, it counts for
    // nothing — which is the whole reason the app now asks first.
    await state.setValue(habit, yesterday, 1);
    expect(state.habitTotals(habit).scheduled, 1);

    await state.trackHabitFrom(habit, yesterday);
    final back = state.everyHabit.single;
    expect(back.isActiveOn(yesterday), isTrue);
    expect(state.habitTotals(back).scheduled, 2);
    expect(state.habitTotals(back).completed, 1);
    expect(state.habitStreak(back), 1, reason: 'yesterday now counts');
  });

  testWidgets('a day before the habit began asks before it writes', (
    tester,
  ) async {
    final state = await emptyState();
    final habit = await state.addHabit(
      name: 'Read',
      iconKey: 'book',
      target: 1,
      unit: '',
    );
    await pumpAppWith(tester, state);

    final before = state.today.subtract(const Duration(days: 3));
    HabitDetailScreen.open(
      tester.element(find.byType(Scaffold).first),
      habitId: habit.id,
      day: before,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckButton).first);
    await tester.pumpAndSettle();
    expect(find.text(AppContent.trackEarlierNo), findsOneWidget);

    // Said no: nothing written, and the habit still starts where it did.
    await tester.tap(find.text(AppContent.trackEarlierNo));
    await tester.pumpAndSettle();
    expect(state.valueOf(habit.id, before), 0);

    await tester.tap(find.byType(CheckButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppContent.trackEarlierYes));
    await tester.pumpAndSettle();

    expect(state.everyHabit.single.isActiveOn(before), isTrue);
    expect(state.valueOf(habit.id, before), 1);
    await letToastPass(tester);
  });
}
