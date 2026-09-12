import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:rewiremind/screens/calendar_screen.dart';
import 'package:rewiremind/screens/home_screen.dart';

import 'helpers.dart';

/// A day is looked at on the Calendar and changed on Home. Every date on the
/// Calendar — the month grid, the dates over the board, the dates over the
/// overview — goes to the same place, because Home is the screen with the
/// habits on it and the + in the corner.
void main() {
  testWidgets('a date on the month grid opens that day on Home', (
    tester,
  ) async {
    final state = await seededState();
    await pumpAppWith(tester, state);

    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    // A day earlier this month, whichever month it is.
    final earlier = state.today.subtract(const Duration(days: 4));
    await tester.tap(
      find
          .descendant(
            of: find.byType(CalendarScreen),
            matching: find.text('${earlier.day}'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(state.viewedDay, earlier);
    // Home is showing it: its date header is that day, not today.
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.text(DateFormat('EEE, d MMM').format(earlier)),
      ),
      findsOneWidget,
    );
  });
}
