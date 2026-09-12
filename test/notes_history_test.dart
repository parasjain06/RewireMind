import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Notes are the only place in the app that holds the user's own words. They
/// were stored and never shown; these keep them visible.
void main() {
  Future<Habit> openFirstHabit(WidgetTester tester, AppState state) async {
    final habit = state.habits.first;
    await tester.tap(find.text(habit.name));
    await tester.pumpAndSettle();
    return habit;
  }

  /// Drags the detail list until [target] has been built.
  ///
  /// `scrollUntilVisible` needs to be told which scrollable to drive and there
  /// is more than one candidate on this screen, so the list is driven directly.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 14 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    expect(target, findsWidgets, reason: 'never scrolled into view');
    // Built is not the same as tappable — bring it fully inside the viewport.
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
  }

  testWidgets('a habit with no notes still offers a way to write one', (
    tester,
  ) async {
    final state = await pumpSeededApp(tester);
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text(AppContent.detailNotesTitle));

    // The card stays even when empty: hiding it meant the only way to write a
    // note was long-pressing the row on Home, which nobody finds.
    expect(find.text(AppContent.detailNotesEmpty), findsOneWidget);
    expect(find.text(AppContent.detailNotesAdd), findsOneWidget);
  });

  testWidgets('Add note opens the editor for today', (tester) async {
    final state = await pumpSeededApp(tester);
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text(AppContent.detailNotesAdd));

    await tester.tap(find.text(AppContent.detailNotesAdd));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Add note'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Wrote it here');
    await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
    await tester.pumpAndSettle();

    expect(state.notesOn(state.habits.first.id, state.today), [
      'Wrote it here',
    ]);
  });

  testWidgets('notes are listed newest first, with the day they belong to', (
    tester,
  ) async {
    final state = await seededState();
    final habit = state.habits.first;
    final today = state.today;

    await state.addNote(habit, today, 'Felt easy today');
    await state.addNote(
      habit,
      today.subtract(const Duration(days: 3)),
      'Skipped, calf sore',
    );

    await pumpAppWith(tester, state);
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text(AppContent.detailNotesTitle));

    expect(find.text('Felt easy today'), findsOneWidget);
    expect(find.text('Skipped, calf sore'), findsOneWidget);

    // Newest first: the later note is higher up the card.
    final newest = tester.getTopLeft(find.text('Felt easy today')).dy;
    final older = tester.getTopLeft(find.text('Skipped, calf sore')).dy;
    expect(newest, lessThan(older));
  });

  testWidgets('a day can hold several notes', (tester) async {
    // The second thing somebody writes about a day is usually that it
    // changed. It used to overwrite the first.
    final state = await seededState();
    final habit = state.habits.first;

    await state.addNote(habit, state.today, 'Skipped the morning run');
    await state.addNote(habit, state.today, 'Did it in the evening after all');

    expect(state.notesOn(habit.id, state.today), [
      'Skipped the morning run',
      'Did it in the evening after all',
    ]);
    // Newest first in the history, as with days.
    expect(state.notesFor(habit.id).map((n) => n.text).take(2), [
      'Did it in the evening after all',
      'Skipped the morning run',
    ]);
    expect(state.noteCount, 2);
  });

  testWidgets('deleting one note leaves the rest, and Undo puts it back', (
    tester,
  ) async {
    final state = await pumpSeededApp(tester);
    final habit = state.habits.first;
    await state.addNote(habit, state.today, 'First');
    await state.addNote(habit, state.today, 'Second');
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text('First'));

    // The trash can on the "First" row.
    final row = find.ancestor(
      of: find.text('First'),
      matching: find.byType(InkWell),
    );
    await tester.tap(
      find.descendant(
        of: row.first,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pump();

    expect(state.notesOn(habit.id, state.today), ['Second']);
    expect(find.text('Note deleted'), findsOneWidget);

    // Let the snackbar finish arriving, then press its own Undo — the
    // detail screen has another "Undo" of its own.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pump();
    expect(state.notesOn(habit.id, state.today), [
      'First',
      'Second',
    ], reason: 'back where it was, not on the end');
    await letToastPass(tester);
  });

  testWidgets('a note can be deleted from its editor too', (tester) async {
    final state = await pumpSeededApp(tester);
    final habit = state.habits.first;
    await state.addNote(habit, state.today, 'Only one');
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text('Only one'));

    await tester.tap(find.text('Only one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();

    expect(state.hasNote(habit.id, state.today), isFalse);
    expect(find.text('Only one'), findsNothing);
  });

  test('notes saved before a day could hold several still load', () async {
    // One string per day was the old shape, in storage and in backups.
    SharedPreferences.setMockInitialValues({
      'notes': '{"h1": {"2026-09-01": "Old style note"}}',
    });
    final storage = await RewireMindStorage.open();
    expect(storage.loadNotes(), {
      'h1': {
        '2026-09-01': ['Old style note'],
      },
    });
  });

  testWidgets('a long history folds away behind a toggle', (tester) async {
    final state = await seededState();
    final habit = state.habits.first;

    for (var i = 0; i < 5; i++) {
      await state.addNote(
        habit,
        state.today.subtract(Duration(days: i)),
        'Note number $i',
      );
    }

    await pumpAppWith(tester, state);
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text(AppContent.detailNotesTitle));

    // Three shown, the rest folded — the screen is meant to fit one page.
    expect(find.text('Note number 0'), findsOneWidget);
    expect(find.text('Note number 2'), findsOneWidget);
    expect(find.text('Note number 4'), findsNothing);

    await scrollTo(tester, find.text(AppContent.detailNotesShowAll(5)));
    await tester.tap(find.text(AppContent.detailNotesShowAll(5)));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Note number 4'));
    expect(find.text('Note number 4'), findsOneWidget);
  });

  testWidgets('tapping a note opens that day for editing', (tester) async {
    final state = await seededState();
    final habit = state.habits.first;
    final when = state.today.subtract(const Duration(days: 2));
    await state.addNote(habit, when, 'Ran in the rain');

    await pumpAppWith(tester, state);
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text('Ran in the rain'));

    await tester.tap(find.text('Ran in the rain'));
    await tester.pumpAndSettle();

    // The sheet opens on that day, prefilled — not on today.
    expect(find.text(habit.name), findsWidgets);
    expect(find.text('Save note'), findsOneWidget);
    expect(
      find.text('Ran in the rain'),
      findsWidgets,
      reason: 'the editor opens on the note it was tapped from',
    );
  });

  testWidgets('deleting the note removes it from the history', (tester) async {
    final state = await seededState();
    final habit = state.habits.first;
    await state.addNote(habit, state.today, 'Temporary');

    expect(state.notesFor(habit.id), hasLength(1));
    await state.editNote(habit, state.today, 0, '');
    expect(state.notesFor(habit.id), isEmpty);

    await pumpAppWith(tester, state);
    await openFirstHabit(tester, state);
    await scrollTo(tester, find.text(AppContent.detailNotesTitle));

    // The card stays, but with nothing in it.
    expect(find.text('Temporary'), findsNothing);
    expect(find.text(AppContent.detailNotesEmpty), findsOneWidget);
  });
}
