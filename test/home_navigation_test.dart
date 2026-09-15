import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/screens/home_screen.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/widgets/app_background.dart';

import 'helpers.dart';

/// The date on Home is the way through to the month view. It is the only
/// route to the Calendar that is not the nav bar, so it has to actually fire.
void main() {
  Future<void> pumpHome(
    WidgetTester tester,
    AppState state, {
    VoidCallback? onOpenCalendar,
  }) async {
    disableQuoteAutoAdvance();
    disableHeroWalk();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: state.theme.toThemeData(),
          home: AppBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: HomeScreen(onOpenCalendar: onOpenCalendar),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the date asks for the calendar', (tester) async {
    final state = await seededState();
    var opened = 0;
    await pumpHome(tester, state, onOpenCalendar: () => opened++);

    final label = 'Today, ${DateFormat('d MMM').format(state.today)}';
    expect(find.text(label), findsOneWidget);

    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(opened, 1, reason: 'the date header is the route to the month view');
  });

  testWidgets('the date carries a chevron so it reads as a way through', (
    tester,
  ) async {
    final state = await seededState();
    await pumpHome(tester, state, onOpenCalendar: () {});

    expect(find.byIcon(Icons.chevron_right), findsWidgets);
  });

  testWidgets('without a destination it is plain text, not a dead control', (
    tester,
  ) async {
    final state = await seededState();
    await pumpHome(tester, state);

    final label = 'Today, ${DateFormat('d MMM').format(state.today)}';
    expect(find.text(label), findsOneWidget);
    expect(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      findsNothing,
      reason: 'a tappable-looking heading that does nothing is worse than none',
    );
  });

  testWidgets('selecting another day still selects rather than navigating', (
    tester,
  ) async {
    final state = await seededState();
    var opened = 0;
    await pumpHome(tester, state, onOpenCalendar: () => opened++);

    // A different day in the week strip.
    final other = state.today.subtract(const Duration(days: 1));
    if (other.isBefore(startOfWeek(state.today))) return;

    // The last one: the streak above the strip is a number too, and on a day
    // whose date happens to match it, .first taps that instead of the day.
    await tester.tap(find.text('${other.day}').last);
    await tester.pumpAndSettle();

    expect(
      opened,
      0,
      reason: 'the week strip picks a day; it does not navigate',
    );
    // The section heading is just "Habits" whichever day is showing — the
    // date line above it is what names the day, so that is what has to move.
    expect(
      find.textContaining('Today,'),
      findsNothing,
      reason: 'the list follows the selected day',
    );
    expect(
      find.textContaining(DateFormat('d MMM').format(other)),
      findsWidgets,
      reason: 'and says which day it is showing',
    );
  });
}
