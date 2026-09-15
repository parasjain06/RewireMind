import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/content/habit_library.dart';
import 'package:rewiremind/models/habit_log.dart';

import 'helpers.dart';

/// A habit only counts from the day it starts. One added while Home is showing
/// last Tuesday used to start today regardless — so it was not on the day you
/// were looking at, the list did not move, and the obvious conclusion was that
/// adding it had failed. The day is now the question, and the answer goes all
/// the way into the habit's start date.
void main() {
  String label(DateTime d) => DateFormat('EEE d MMM').format(d);

  testWidgets('adding from today asks nothing', (tester) async {
    final state = await pumpSeededApp(tester);
    expect(state.viewingToday, isTrue);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.textContaining('Start it on'), findsNothing);
    expect(find.text(HabitLibrary.screenTitle), findsOneWidget);
  });

  testWidgets('adding from an earlier day names that day', (tester) async {
    final state = await pumpSeededApp(tester);
    final back = state.today.subtract(const Duration(days: 2));
    state.viewDay(back);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text(AppContent.backdateTitle(label(back))), findsOneWidget);
    expect(
      find.text(HabitLibrary.screenTitle),
      findsNothing,
      reason: 'nothing opens until it is answered',
    );
  });

  testWidgets('"Start today" makes an ordinary habit', (tester) async {
    final state = await pumpSeededApp(tester);
    state.viewDay(state.today.subtract(const Duration(days: 3)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppContent.backdateStartToday));
    await tester.pumpAndSettle();

    expect(find.text(HabitLibrary.screenTitle), findsOneWidget);

    final before = state.everyHabit.length;
    await _addFirstPreset(tester);
    expect(state.everyHabit, hasLength(before + 1));
    expect(
      dateOnly(state.everyHabit.last.createdAt),
      state.today,
      reason: 'starting today is what "start today" has to mean',
    );
  });

  testWidgets('"Start 8 Sep" back-dates it, so those days count', (
    tester,
  ) async {
    final state = await pumpSeededApp(tester);
    final back = state.today.subtract(const Duration(days: 3));
    state.viewDay(back);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(AppContent.backdateStartThen(DateFormat('d MMM').format(back))),
    );
    await tester.pumpAndSettle();

    await _addFirstPreset(tester);
    final added = state.everyHabit.last;

    expect(dateOnly(added.createdAt), back);

    // Everything downstream follows from that one field: the habit is
    // scheduled on the day it started and not on the day before it.
    expect(added.isActiveOnDay(back), isTrue);
    expect(
      added.isActiveOnDay(back.subtract(const Duration(days: 1))),
      isFalse,
    );
    expect(
      state.scheduledOn(back).map((h) => h.id),
      contains(added.id),
      reason: 'the day you were looking at now counts it',
    );
  });
}

/// Adds the first preset in the library via the editor sheet.
Future<void> _addFirstPreset(WidgetTester tester) async {
  final add = find.descendant(
    of: find.byType(ListView),
    matching: find.byIcon(Icons.add),
  );
  await tester.tap(add.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppContent.editorCreate));
  await tester.pumpAndSettle();
  await letToastPass(tester);
}
