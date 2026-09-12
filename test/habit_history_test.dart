import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/screens/habit_detail_screen.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/theme/app_theme.dart';
import 'package:rewiremind/theme/habit_shade.dart';

import 'helpers.dart';

/// The six-week grid on the detail screen used to tick a day when you tapped
/// it. On "read 10 pages" standing at six, a toggle has to either throw the
/// six away or invent the other four — from a control that looks like a
/// legend. These pin down that it now selects the day instead, and that the
/// day it opens on is the one it was asked for.
void main() {
  const target = 10.0;

  Future<AppState> withPartDay() async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    disableQuoteAutoAdvance();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    final now = dateOnly(DateTime.now());

    await storage.saveHabits([
      Habit(
        id: 'h',
        name: 'Read 10 pages',
        iconKey: 'book',
        target: target,
        unit: 'pages',
        createdAt: now.subtract(const Duration(days: 40)),
        sortOrder: 0,
      ),
    ]);
    // Six of ten, three weeks back: far enough that it is not today, and part
    // done, which is the case a toggle cannot express.
    await storage.saveLogs({
      'h': {dayKey(now.subtract(const Duration(days: 21))): 6.0},
    });
    await storage.markSeeded();

    final state = AppState(storage);
    await state.load();
    return state;
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    AppState state, {
    DateTime? day,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: RewireMindTheme.byId('forest').toThemeData(),
          home: HabitDetailScreen(habitId: 'h', day: day),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a square in the history changes nothing when pressed', (
    tester,
  ) async {
    final state = await withPartDay();
    final part = state.today.subtract(const Duration(days: 21));
    expect(state.valueOf('h', part), 6);

    // Opened on that day, so the week it belongs to is the week on screen.
    await pumpDetail(tester, state, day: part);

    final square = find.byTooltip(_tooltipFor(part));
    expect(square, findsOneWidget);

    await tester.tap(square);
    await tester.pumpAndSettle();

    expect(
      state.valueOf('h', part),
      6,
      reason: 'six pages is still six pages: the grid records, it never logs',
    );
  });

  /// The outermost Container of a cell — the block itself, carrying the fill
  /// and, when it is the day being logged, the ring.
  BoxDecoration blockOf(WidgetTester tester, Finder cell) =>
      tester
              .widget<Container>(
                find
                    .descendant(of: cell, matching: find.byType(Container))
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('tapping another day moves the card to it', (tester) async {
    // The grid picks the day the screen works on. It still never logs
    // anything itself — see the test above — it only chooses which day the
    // card at the top is showing.
    final state = await withPartDay();
    final part = state.today.subtract(const Duration(days: 21));
    final other = part.add(const Duration(days: 1));

    await pumpDetail(tester, state, day: part);
    await tester.tap(find.byTooltip(_tooltipFor(other)));
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('EEEE, d MMMM').format(other)), findsOneWidget);
    expect(find.text(DateFormat('EEEE, d MMMM').format(part)), findsNothing);

    // And the ring went with it.
    expect(
      blockOf(tester, find.byTooltip(_tooltipFor(other))).border,
      isNotNull,
    );
    expect(blockOf(tester, find.byTooltip(_tooltipFor(part))).border, isNull);
  });

  testWidgets('a day that has not happened yet cannot be picked', (
    tester,
  ) async {
    final state = await withPartDay();
    await pumpDetail(tester, state);

    // Today's week is on screen; tomorrow is in it unless today is Sunday.
    final tomorrow = state.today.add(const Duration(days: 1));
    if (tomorrow.weekday == DateTime.monday) return;

    await tester.tap(find.byTooltip(_tooltipFor(tomorrow)));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('EEEE, d MMMM').format(tomorrow)),
      findsNothing,
      reason: 'nothing to log on a day that has not happened',
    );
  });

  testWidgets('a part-done day wears the habit colour at its own depth', (
    tester,
  ) async {
    final state = await withPartDay();
    final part = state.today.subtract(const Duration(days: 21));

    await pumpDetail(tester, state, day: part);

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byTooltip(_tooltipFor(part)),
        matching: find.byType(Container),
      ),
    );
    final fill = (box.decoration! as BoxDecoration).color!;

    expect(
      fill,
      habitShade(state.colorFor(state.everyHabit.first), 0.6),
      reason: 'six of ten is the habit hue at six tenths of the ramp',
    );
  });

  testWidgets('the card says which days it is showing, in dates', (
    tester,
  ) async {
    final state = await withPartDay();
    final part = state.today.subtract(const Duration(days: 21));
    final monday = startOfWeek(part);

    await pumpDetail(tester, state, day: part);

    // A week by default, and the span written out — the old grid said
    // "M T W T F S S" and left you to work out which M.
    expect(find.text('This week'), findsOneWidget);
    expect(
      find.text(
        '${DateFormat('d MMM').format(monday)} – '
        '${DateFormat('d MMM yyyy').format(monday.add(const Duration(days: 6)))}',
      ),
      findsOneWidget,
    );

    // And every block carries its own date.
    expect(find.text('${part.day}'), findsWidgets);
  });

  /// Whether a cell carries today's dot.
  bool hasDot(Finder cell) => find
      .descendant(
        of: cell,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('the day being logged and today are not the same mark', (
    tester,
  ) async {
    // The confusion this fixes: opening a habit from a day on the board ringed
    // that day, and ringed today as well in the same green — two green marks
    // differing by an alpha value, which is not a difference anybody reads.
    //
    // The grid ends at the week of the day being logged, so today is only ever
    // on screen when that day falls in the current week. Monday is the one day
    // where "the start of this week" and "today" are the same date, and the
    // assertion flips accordingly rather than the test skipping.
    final state = await withPartDay();
    final selected = startOfWeek(state.today);
    await pumpDetail(tester, state, day: selected);

    final picked = find.byTooltip(_tooltipFor(selected));
    final now = find.byTooltip(_tooltipFor(state.today));
    expect(picked, findsOneWidget);
    expect(now, findsOneWidget);

    // The ring belongs to the day being logged, and to nothing else.
    expect(blockOf(tester, picked).border, isNotNull);
    expect(hasDot(picked), selected == state.today);

    if (selected != state.today) {
      expect(
        blockOf(tester, now).border,
        isNull,
        reason: 'today wearing a ring too is the whole bug',
      );
      expect(hasDot(now), isTrue, reason: 'today is a dot, not a ring');
    }
  });

  testWidgets('opened on today, one block carries both marks', (tester) async {
    // The usual visit: the day being logged is today, so the ring and the dot
    // land on the same block, which is the honest reading of it.
    final state = await withPartDay();
    await pumpDetail(tester, state);

    final now = find.byTooltip(_tooltipFor(state.today));
    expect(blockOf(tester, now).border, isNotNull);
    expect(hasDot(now), isTrue);
  });

  testWidgets('the grid explains itself, without a key under it', (
    tester,
  ) async {
    // There was a legend here — two swatches and two labels under a row of
    // seven blocks, which is more furniture than the thing it explained. A
    // ring and a dot are different enough to read, and the card above the grid
    // already names the day being logged in words.
    final state = await withPartDay();
    await pumpDetail(tester, state, day: startOfWeek(state.today));

    expect(find.text('The day you are logging'), findsNothing);
  });

  testWidgets('the span picker reaches back four weeks', (tester) async {
    final state = await withPartDay();
    final part = state.today.subtract(const Duration(days: 21));

    // Opened on today, so three weeks back is off the default week.
    await pumpDetail(tester, state);
    expect(find.byTooltip(_tooltipFor(part)), findsNothing);

    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 4 weeks').last);
    await tester.pumpAndSettle();

    expect(find.byTooltip(_tooltipFor(part)), findsOneWidget);
  });
}

/// The same format the cell's tooltip uses.
String _tooltipFor(DateTime day) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[day.weekday - 1]} ${day.day} ${months[day.month - 1]}';
}
