import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/habit_library.dart';

import 'helpers.dart';

/// A row that says "Added" with no way past it is a dead end on the one
/// screen whose whole job is changing what you track. The cross beside the
/// tick undoes it — and what "undo" means depends on whether there is
/// anything to lose.
void main() {
  /// Adds the named preset, and dismisses the "remind you?" dialog that
  /// follows it — that dialog is a modal barrier, and every tap after it goes
  /// into the barrier rather than the screen.
  Future<void> addPreset(WidgetTester tester, String name) async {
    final row = find.ancestor(of: find.text(name), matching: find.byType(Row));
    await tester.tap(
      find.descendant(of: row.first, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    }
    await letToastPass(tester);
  }

  /// Presses the cross on the first added row.
  ///
  /// By icon rather than by tooltip: `find.byTooltip` returns the Tooltip,
  /// whose render box is an overlay surrogate — tapping its centre misses the
  /// button underneath it.
  Future<void> tapRemove(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
  }

  testWidgets('a preset added by mistake goes straight back off', (
    tester,
  ) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);
    await openLibrary(tester);

    // Add the first preset, then take it off again.
    await addPreset(tester, 'Drink water');
    expect(state.everyHabit, hasLength(1));

    await tapRemove(tester);
    await tester.pumpAndSettle();
    await letToastPass(tester);

    expect(
      state.everyHabit,
      isEmpty,
      reason:
          'nothing was ever logged against it, so nothing was worth '
          'keeping',
    );
  });

  testWidgets('one with history is discontinued, not binned', (tester) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);
    await openLibrary(tester);

    await addPreset(tester, 'Drink water');

    final habit = state.everyHabit.single;
    await state.setValue(habit, state.today, habit.target);
    expect(state.hasHistory(habit.id), isTrue);

    await tapRemove(tester);
    await tester.pumpAndSettle();
    await letToastPass(tester);

    // Off the list you track, still in the record you have kept.
    expect(state.habits, isEmpty);
    expect(state.everyHabit, hasLength(1));
    expect(state.everyHabit.single.isArchived, isTrue);
    expect(
      state.valueOf(habit.id, state.today),
      habit.target,
      reason: 'the day it was done still happened',
    );
  });

  testWidgets('and the row offers it again afterwards', (tester) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);
    await openLibrary(tester);

    await addPreset(tester, 'Drink water');
    expect(find.text(HabitLibrary.added), findsOneWidget);

    await tapRemove(tester);
    await tester.pumpAndSettle();
    await letToastPass(tester);

    expect(find.text(HabitLibrary.added), findsNothing);
  });
}
