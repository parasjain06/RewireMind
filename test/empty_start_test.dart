import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/content/habit_library.dart';
import 'package:rewiremind/models/progress_range.dart';

import 'helpers.dart';

/// With `seedDemoData` off, a fresh install has no habits at all. Every screen
/// still has to render — divide-by-zero in a completion rate or an empty
/// reduce() would crash the app on first launch, which is the worst possible
/// moment for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an empty install reports zeroes rather than throwing', () async {
    final state = await emptyState();

    expect(state.habits, isEmpty);
    expect(state.everyHabit, isEmpty);
    expect(state.currentStreak, 0);
    expect(state.bestStreak, 0);
    expect(state.daysActive, 1);
    expect(state.completedCountOn(state.today), 0);

    for (final range in ProgressRange.values) {
      final stats = state.statsFor(range);
      expect(stats.scheduled, 0, reason: range.name);
      expect(stats.percent, 0, reason: range.name);
      expect(stats.breakdown, isEmpty, reason: range.name);
      expect(stats.series, isNotEmpty, reason: '${range.name} still charts');
    }
  });

  testWidgets('every tab renders with no habits', (tester) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);
    expect(tester.takeException(), isNull, reason: 'Home');

    for (final tab in ['Calendar', 'Progress', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('Home invites you to add your first habit', (tester) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);

    expect(find.text(AppContent.emptyDayTitle), findsOneWidget);
    expect(find.text(AppContent.emptyDayBody), findsOneWidget);
    expect(find.textContaining('0 of 0'), findsOneWidget);
  });

  testWidgets('adding the first habit from the library fills Home', (
    tester,
  ) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);

    // The add button now lives in the bottom bar, reachable from any tab.
    await openHabitLibrary(tester);
    expect(find.text(HabitLibrary.screenTitle), findsOneWidget);

    final row = find.ancestor(
      of: find.text('Drink water'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();

    // Creating a habit now offers a reminder for it.
    expect(find.text('Remind you?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await letToastPass(tester);

    expect(state.habits, hasLength(1));
    expect(state.habits.first.name, 'Drink water');

    // Back to Home: the habit is listed and countable.
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Drink water'), findsOneWidget);
    expect(find.textContaining('0 of 1'), findsOneWidget);
  });

  testWidgets('a first cut-back habit gets the right wording', (tester) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);

    await openHabitLibrary(tester);
    await tester.tap(find.text(HabitLibrary.customButton));
    await tester.pumpAndSettle();

    // `.last` because the library's own "Cut back" chip is still in the tree
    // underneath the editor, and both carry the same word.
    await tester.tap(find.text(AppContent.editorKindQuit).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Less doomscrolling');
    await tester.tap(find.text(AppContent.editorCreate));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(state.habits, hasLength(1));
    final habit = state.habits.first;
    expect(habit.target, 1, reason: 'cut-back habits are one daily tick');
    expect(habit.unit, isEmpty);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(find.text(AppContent.quitPending), findsOneWidget);
  });
}
