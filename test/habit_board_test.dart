import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/theme/app_theme.dart';
import 'package:rewiremind/widgets/habit_board.dart';

import 'helpers.dart';

/// The board says how much of a habit was done by how deep its colour is, so
/// the two things worth pinning down are the colour a habit gets and the fact
/// that a partly-done day is neither full nor empty.
/// The board on its own, with a real AppState behind it.
Future<void> pumpBoard(
  WidgetTester tester,
  AppState state,
  void Function(Habit habit, DateTime day) onOpenDay,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: RewireMindTheme.byId('forest').toThemeData(),
        home: Scaffold(
          body: HabitBoard(onOpenDay: onOpenDay, onOpenDate: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  Future<AppState> withHabit({int? colour, double target = 5}) async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    final now = dateOnly(DateTime.now());

    await storage.saveHabits([
      Habit(
        id: 'h',
        name: 'Drink water',
        iconKey: 'water',
        target: target,
        unit: 'glasses',
        createdAt: now.subtract(const Duration(days: 10)),
        sortOrder: 0,
        colorValue: colour,
      ),
    ]);
    await storage.saveLogs({
      'h': {
        // Full yesterday, two of five the day before, nothing before that.
        dayKey(now.subtract(const Duration(days: 1))): target,
        dayKey(now.subtract(const Duration(days: 2))): 2,
      },
    });
    await storage.markSeeded();

    final state = AppState(storage);
    await state.load();
    return state;
  }

  test(
    'a habit with no colour of its own takes its place in the ramp',
    () async {
      final state = await withHabit();
      expect(state.everyHabit.first.colorValue, isNull);
      expect(
        state.colorFor(state.everyHabit.first),
        Color(AppContent.habitColours.first),
        reason:
            'the board reads as one gradient down the page, so an unpicked '
            'habit takes the next colour along rather than its icon accent',
      );
    },
  );

  test('a chosen colour wins, and survives a reopen', () async {
    final chosen = AppContent.habitColours.first;
    final state = await withHabit(colour: chosen);
    expect(state.colorFor(state.everyHabit.first), Color(chosen));

    final again = await reopen();
    expect(again.everyHabit.first.colorValue, chosen);
  });

  test('clearing a colour hands it back to the theme', () async {
    final state = await withHabit(colour: AppContent.habitColours.last);
    final bare = state.everyHabit.first.copyWith(clearColor: true);
    expect(bare.colorValue, isNull);
  });

  test('the board shows a partly-done day as neither full nor empty', () async {
    final state = await withHabit(target: 5);
    final habit = state.everyHabit.first;
    final now = state.today;

    expect(state.valueOf(habit.id, now.subtract(const Duration(days: 1))), 5);
    expect(state.valueOf(habit.id, now.subtract(const Duration(days: 2))), 2);
    expect(state.valueOf(habit.id, now.subtract(const Duration(days: 3))), 0);
  });

  testWidgets('a block before the habit began opens nothing', (tester) async {
    final state = await withHabit();
    final opened = <(String, DateTime)>[];
    await pumpBoard(tester, state, (h, d) => opened.add((h.id, d)));

    // Ten days old, on a board seventy days wide: the left-hand end of the
    // row is a fortnight before it existed. Tapping there used to open the
    // habit on a day nothing could be logged against.
    final name = tester.getRect(find.text('Drink water'));
    await tester.tapAt(Offset(name.right + 24, name.center.dy));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.textContaining('tracked since'), findsOneWidget);
    await letToastPass(tester);
  });

  testWidgets('a block reports its own day and writes nothing', (tester) async {
    final state = await withHabit();
    final habit = state.everyHabit.first;
    final partDone = state.today.subtract(const Duration(days: 2));

    // Two of five: the case a toggle could not handle without either throwing
    // the two away or inventing the other three.
    expect(state.valueOf(habit.id, partDone), 2);

    final opened = <(String, DateTime)>[];
    await pumpBoard(tester, state, (h, d) => opened.add((h.id, d)));

    // The name column is the one thing on the board with text in it, which
    // makes it the anchor for finding the band beside it. The right-hand end
    // of that band is today; the left runs back past the day the habit
    // started, where a block has nothing to open.
    final name = tester.getRect(find.text('Drink water'));
    final board = tester.getRect(find.byType(HabitBoard));
    await tester.tapAt(Offset(board.right - 24, name.center.dy));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1), reason: 'a block opens exactly one day');
    expect(opened.single.$1, habit.id);
    expect(
      opened.single.$2.isAfter(state.today),
      isFalse,
      reason: 'and the day it reports is one the board actually shows',
    );

    expect(
      state.valueOf(habit.id, partDone),
      2,
      reason: 'the grid picks a day; it does not log one',
    );
    expect(
      state.valueOf(habit.id, state.today),
      0,
      reason: 'nor does it fill in the day that happened to be under the tap',
    );
  });

  testWidgets('the name reports today, so the detail screen opens on now', (
    tester,
  ) async {
    final state = await withHabit();
    final opened = <(String, DateTime)>[];
    await pumpBoard(tester, state, (h, d) => opened.add((h.id, d)));

    await tester.tap(find.text('Drink water'));
    await tester.pumpAndSettle();

    expect(opened, [(state.everyHabit.first.id, state.today)]);
  });

  test('the board covers a whole number of weeks', () {
    expect(
      HabitBoard.days % 7,
      0,
      reason:
          'the columns sit under weekday letters, so a part week would '
          'put every letter over the wrong day',
    );
  });

  test('every colour in the palette is opaque', () {
    // They are used at a computed alpha to mean "how much of it was done", so
    // a swatch that arrived semi-transparent would read as a lighter day.
    for (final value in AppContent.habitColours) {
      expect(Color(value).a, 1.0, reason: '$value');
    }
  });
}
