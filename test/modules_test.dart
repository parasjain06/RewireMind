import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/content/habit_library.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/models/progress_range.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Covers the add-habit, habit-detail and day-backfill modules.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The + now opens the habit library; the blank form sits behind
  /// "Custom habit".
  Future<void> openCustomEditor(WidgetTester tester) async {
    await openHabitLibrary(tester);
    await tester.tap(find.text(HabitLibrary.customButton));
    await tester.pumpAndSettle();
  }

  group('add habit', () {
    testWidgets('creates a habit from the editor sheet', (tester) async {
      final state = await pumpSeededApp(tester);
      expect(state.habits.length, 6);

      await openCustomEditor(tester);
      expect(find.text(AppContent.editorNewTitle), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Walk 5000 steps');
      await tester.tap(find.text(AppContent.editorCreate));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.habits.length, 7);
      expect(state.habits.last.name, 'Walk 5000 steps');
      // A brand new habit starts with no history.
      expect(state.habitTotals(state.habits.last).completed, 0);
    });

    testWidgets('refuses an empty name', (tester) async {
      final state = await pumpSeededApp(tester);

      await openCustomEditor(tester);
      await tester.tap(find.text(AppContent.editorCreate));
      await tester.pumpAndSettle();

      expect(find.text(AppContent.editorNameRequired), findsOneWidget);
      expect(state.habits.length, 6, reason: 'nothing should be created');
    });

    testWidgets('a new habit persists across a reload', (tester) async {
      await pumpSeededApp(tester);

      await openCustomEditor(tester);
      await tester.enterText(find.byType(TextField).first, 'Stretch');
      await tester.tap(find.text(AppContent.editorCreate));
      await tester.pumpAndSettle();

      final reloaded = await reopen();
      expect(reloaded.habits.map((h) => h.name), contains('Stretch'));
    });
  });

  group('habit detail', () {
    testWidgets('opens from a habit row and shows its stats', (tester) async {
      await pumpSeededApp(tester);

      await tester.tap(find.text('Drink 2L water'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The three figures now sit in one compact band rather than three cards.
      expect(find.text(AppContent.detailStreakShort), findsOneWidget);
      expect(find.text(AppContent.detailBestShort), findsOneWidget);
      expect(find.text(AppContent.detailCompletionShort), findsOneWidget);
      // The history grid says which days it is drawing, in dates, and offers
      // the span picker that changes them.
      expect(find.text(AppContent.detailHistoryTitle), findsOneWidget);
      expect(find.text(AppContent.historySpanWeek), findsOneWidget);
      expect(
        find.textContaining(' – '),
        findsOneWidget,
        reason: 'the span is written out as two dates',
      );
    });

    testWidgets('the stepper moves progress toward the target', (tester) async {
      final state = await pumpSeededApp(tester);
      final habit = state.habits.firstWhere((h) => h.id == 'habit_water');
      expect(state.valueOf(habit.id, state.today), 0);

      await tester.tap(find.text('Drink 2L water'));
      await tester.pumpAndSettle();

      // Target is 2 L, so each press adds 1. The stepper's own plus, not the
      // nav bar's — this screen is pushed over it.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(state.valueOf(habit.id, state.today), 1);
      expect(state.isComplete(habit, state.today), isFalse);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(state.isComplete(habit, state.today), isTrue);
    });

    testWidgets('deleting removes the habit and its history', (tester) async {
      final state = await pumpSeededApp(tester);

      await tester.tap(find.text('Read 10 pages'));
      await tester.pumpAndSettle();
      // Discontinue now sits above Delete, pushing it past the fold.
      await tester.scrollUntilVisible(
        find.text(AppContent.detailDelete),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppContent.detailDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppContent.detailDeleteConfirm));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.habits.length, 5);
      expect(state.habits.any((h) => h.name == 'Read 10 pages'), isFalse);
    });
  });

  group('day selection and backfill', () {
    testWidgets('picking a past day lists that day and can backfill', (
      tester,
    ) async {
      final state = await pumpSeededApp(tester);

      // The strip only covers the current week, so the target has to sit
      // inside it. Monday is always the earliest cell — and on a Monday it is
      // today, which is why this cannot simply be "yesterday": that test
      // passed six days a week and failed on the seventh.
      final target = startOfWeek(state.today);
      final isPast = target.isBefore(state.today);

      // `.last`: the strip comes after the stat line, whose streak count can
      // be the same number as a date — which it is, on the right day.
      await tester.tap(find.text('${target.day}').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      if (isPast) {
        // The header follows the selection rather than saying "Today".
        expect(find.textContaining('Today,'), findsNothing);
      }

      // Complete every habit for that day, then confirm it reads as "all done".
      for (final habit in state.scheduledOn(target)) {
        if (!state.isComplete(habit, target)) {
          await state.setValue(habit, target, habit.target);
        }
      }
      await tester.pumpAndSettle();
      expect(state.completedCountOn(target), state.scheduledOn(target).length);

      // Returning to today is tapping today's own cell — the ringed one —
      // rather than a button that appears and disappears.
      await tester.tap(find.text('${state.today.day}').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Today,'), findsOneWidget);
    });

    testWidgets('future days cannot be checked off', (tester) async {
      final state = await pumpSeededApp(tester);
      final tomorrow = state.today.add(const Duration(days: 1));
      // Not in this week's strip.
      if (tomorrow.weekday == DateTime.monday) return;

      await tester.tap(find.text('${tomorrow.day}').first);
      await tester.pumpAndSettle();

      final habit = state.scheduledOn(tomorrow).first;
      expect(state.isComplete(habit, tomorrow), isFalse);

      await tester.tap(find.text(habit.name));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('backfilled progress reaches the Progress stats', (
      tester,
    ) async {
      final state = await pumpSeededApp(tester);
      final before = state.statsFor(ProgressRange.week).completed;

      final habit = state.habits.first;
      final gap = _findIncompleteDay(state, habit);
      expect(gap, isNotNull, reason: 'seed history should contain a gap');

      await state.setValue(habit, gap!, habit.target);
      await tester.pumpAndSettle();

      expect(state.isComplete(habit, gap), isTrue);
      final after = state.statsFor(ProgressRange.week).completed;
      // Only assert movement when the gap sits inside the current week.
      if (!gap.isBefore(startOfWeek(state.today))) {
        expect(after, before + 1);
      }
    });
  });
}

/// First day this week the habit was scheduled but not completed.
DateTime? _findIncompleteDay(AppState state, Habit habit) {
  final start = startOfWeek(state.today);
  for (var i = 0; i < 7; i++) {
    final day = start.add(Duration(days: i));
    if (day.isAfter(state.today)) break;
    if (!habit.isScheduledOn(day)) continue;
    if (!state.isComplete(habit, day)) return dateOnly(day);
  }
  return null;
}
