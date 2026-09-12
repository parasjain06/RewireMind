import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/screens/habit_actions_sheet.dart';
import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/screens/home_screen.dart';

import 'helpers.dart';

/// The long-press menu is the fastest route to a habit's lifecycle, and notes
/// are the only place in the app where the user's own words are stored — so
/// both have to survive a reload and neither may quietly lose data.
void main() {
  Future<void> longPressFirstHabit(WidgetTester tester) async {
    await tester.longPress(find.text('Drink 2L water'));
    await tester.pumpAndSettle();
  }

  group('the menu', () {
    testWidgets('a long press opens every action', (tester) async {
      await pumpSeededApp(tester);
      await longPressFirstHabit(tester);

      expect(find.byType(HabitActionsSheet), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Arrange'), findsOneWidget);
      expect(find.text('Discontinue'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap still opens the detail screen', (tester) async {
      await pumpSeededApp(tester);
      await tester.tap(find.text('Drink 2L water'));
      await tester.pumpAndSettle();

      expect(
        find.byType(HabitActionsSheet),
        findsNothing,
        reason: 'a plain tap must not be swallowed by the long press',
      );
    });

    testWidgets('a discontinued habit offers resume rather than discontinue', (
      tester,
    ) async {
      final state = await seededState();
      await state.archiveHabit(state.habits.first);
      await pumpAppWith(tester, state);

      await longPressFirstHabit(tester);
      expect(find.text('Resume tracking'), findsOneWidget);
      expect(find.text('Discontinue'), findsNothing);
    });
  });

  group('arranging', () {
    testWidgets('Arrange puts Home itself into arrange mode', (tester) async {
      await pumpSeededApp(tester);
      await longPressFirstHabit(tester);

      await tester.tap(find.text('Arrange'));
      await tester.pumpAndSettle();

      // No sheet: the handles are on Home's own rows.
      expect(homeArrangeMode.value, isTrue);
      expect(find.text(AppContent.arrangeHint), findsOneWidget);
      expect(
        find.byType(ReorderableDragStartListener),
        findsWidgets,
        reason: 'every row needs a drag handle',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(AppContent.arrangeDone));
      await tester.pumpAndSettle();
      expect(homeArrangeMode.value, isFalse);
      expect(find.text(AppContent.arrangeHint), findsNothing);
    });

    testWidgets('dragging a row on Home saves the new order', (tester) async {
      final state = await seededState();
      await pumpAppWith(tester, state);
      homeArrangeMode.value = true;
      await tester.pumpAndSettle();

      final first = state.habits.first.name;
      final handles = find.byType(ReorderableDragStartListener);
      final start = tester.getCenter(handles.first);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 170));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(state.habits.first.name, isNot(first));
      homeArrangeMode.value = false;
      await tester.pumpAndSettle();
    });

    testWidgets('a new order is applied and renumbered contiguously', (
      tester,
    ) async {
      final state = await seededState();
      final before = state.habits.toList();
      expect(before.length, greaterThan(2));

      // What a drag of the first item to third position produces.
      final dragged = before.toList();
      dragged.insert(2, dragged.removeAt(0));
      await state.reorderHabits(dragged);

      expect(state.habits.map((h) => h.name), dragged.map((h) => h.name));
      final orders = state.habits.map((h) => h.sortOrder).toList();
      expect(orders, List.generate(orders.length, (i) => i));
    });

    testWidgets('the new order survives a reload', (tester) async {
      final state = await seededState();
      final reversed = state.habits.reversed.toList();
      await state.reorderHabits(reversed);
      final expected = state.habits.map((h) => h.name).toList();

      final reloaded = await reopen();
      expect(reloaded.habits.map((h) => h.name), expected);
    });

    testWidgets('an empty order is ignored rather than wiping the list', (
      tester,
    ) async {
      final state = await seededState();
      final before = state.habits.map((h) => h.name).toList();

      await state.reorderHabits(const []);

      expect(state.habits.map((h) => h.name), before);
    });
  });

  group('notes', () {
    testWidgets('a note is written, shown on the row, and persisted', (
      tester,
    ) async {
      final state = await seededState();
      final habit = state.habits.first;

      expect(state.hasNote(habit.id, state.today), isFalse);

      await state.addNote(habit, state.today, '  Ran 5k, felt easy.  ');

      expect(state.notesOn(habit.id, state.today), [
        'Ran 5k, felt easy.',
      ], reason: 'stored trimmed');

      await pumpAppWith(tester, state);
      // Marked with an icon beside the tick rather than a line of text, so a
      // long note cannot push the habit's own detail off the row.
      expect(
        find.byIcon(Icons.sticky_note_2_outlined),
        findsOneWidget,
        reason: 'a note behind a long press has to be marked on the row',
      );

      final reloaded = await reopen();
      expect(reloaded.notesOn(habit.id, reloaded.today), [
        'Ran 5k, felt easy.',
      ]);
    });

    testWidgets('notes belong to a day, not to the habit', (tester) async {
      final state = await seededState();
      final habit = state.habits.first;
      final yesterday = state.today.subtract(const Duration(days: 1));

      await state.addNote(habit, yesterday, 'Skipped, calf sore.');

      expect(state.notesOn(habit.id, yesterday), ['Skipped, calf sore.']);
      expect(
        state.hasNote(habit.id, state.today),
        isFalse,
        reason: "yesterday's excuse does not belong to today",
      );
    });

    testWidgets('emptying a note removes it rather than storing a blank', (
      tester,
    ) async {
      final state = await seededState();
      final habit = state.habits.first;

      await state.addNote(habit, state.today, 'Something');
      await state.editNote(habit, state.today, 0, '   ');

      expect(state.hasNote(habit.id, state.today), isFalse);
      expect(
        state.notesFor(habit.id),
        isEmpty,
        reason: 'a blank note would show an indicator with nothing behind it',
      );
    });

    testWidgets('notes list newest first', (tester) async {
      final state = await seededState();
      final habit = state.habits.first;

      await state.addNote(habit, state.today, 'today');
      await state.addNote(
        habit,
        state.today.subtract(const Duration(days: 2)),
        'older',
      );

      expect(state.notesFor(habit.id).map((e) => e.text), ['today', 'older']);
    });

    testWidgets('deleting a habit takes its notes with it', (tester) async {
      final state = await seededState();
      final habit = state.habits.first;
      await state.addNote(habit, state.today, 'Note');

      await state.deleteHabit(habit);

      expect(state.notesFor(habit.id), isEmpty);

      final reloaded = await reopen();
      expect(
        reloaded.notesOn(habit.id, reloaded.today),
        isEmpty,
        reason: 'an orphaned note would resurface under a recycled id',
      );
    });

    testWidgets('the note editor opens from the menu and saves', (
      tester,
    ) async {
      await pumpSeededApp(tester);
      await longPressFirstHabit(tester);

      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      expect(find.byType(HabitNoteSheet), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Felt good today');
      await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
