import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/data/history_export.dart';
import 'package:rewiremind/screens/calendar_screen.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/theme/app_theme.dart';
import 'package:rewiremind/widgets/habit_board.dart';

import 'helpers.dart';

/// The export is somebody's whole history leaving the app, so what matters is
/// that nothing is missing from it: every day since the first, every habit
/// that was due, and every note.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every due habit-day since the first is in it', () async {
    final state = await seededState();
    final rows = HistoryExport.days(state);

    var expected = 0;
    for (
      var d = state.firstTrackedDay;
      !d.isAfter(state.today);
      d = d.add(const Duration(days: 1))
    ) {
      expected += state.scheduledOn(d).length;
    }
    expect(
      rows.where((r) => r.due),
      hasLength(expected),
      reason: 'a day missing from the export is a day gone from the record',
    );
    expect(rows.first.day, state.firstTrackedDay);
    expect(rows.last.day, state.today);
  });

  test('notes go with the day they were written on', () async {
    final state = await seededState();
    final habit = state.habits.first;
    await state.addNote(habit, state.today, 'First thought');
    await state.addNote(habit, state.today, 'Second thought');

    final today = HistoryExport.days(state)
        .firstWhere((r) => r.day == state.today && r.habit.id == habit.id);
    expect(today.notes, ['First thought', 'Second thought']);
  });

  test('the spreadsheet has a sheet for each part, and every day', () async {
    final state = await seededState();
    final bytes = HistoryExport.excel(state);
    expect(bytes, isNotEmpty);

    final book = xl.Excel.decodeBytes(bytes);
    expect(
      book.tables.keys,
      containsAll(['Summary', 'Habits', 'Daily log', 'Calendar', 'Notes']),
    );

    // One header row, then a row a habit-day.
    expect(
      book.tables['Daily log']!.maxRows - 1,
      HistoryExport.days(state).length,
    );
    // One header row, then a row a calendar day.
    expect(
      book.tables['Calendar']!.maxRows - 1,
      state.today.difference(state.firstTrackedDay).inDays + 1,
    );
    expect(book.tables['Habits']!.maxRows - 1, state.everyHabit.length);
  });

  test('the report is a PDF', () async {
    final state = await seededState();
    final bytes = await HistoryExport.pdf(
      state,
      regular: await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
  });

  test('an empty history still exports without falling over', () async {
    final state = await emptyState();
    expect(HistoryExport.days(state), isEmpty);
    expect(HistoryExport.excel(state), isNotEmpty);
    final pdf = await HistoryExport.pdf(
      state,
      regular: await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'),
    );
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  test('Profile no longer lists Account or Share your board', () {
    final ids = AppContent.profileMenu.map((e) => e.id);
    expect(ids, isNot(contains('account')));
    expect(ids, isNot(contains('share')));
  });

  testWidgets('the Calendar switches between the overview and the board', (
    tester,
  ) async {
    final state = await seededState();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: RewireMindTheme.byId('forest').toThemeData(),
          home: Scaffold(body: CalendarScreen(onOpenDay: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HabitBoard), findsNothing, reason: 'overview first');

    await tester.tap(find.text(AppContent.calendarViewBoard));
    await tester.pumpAndSettle();
    expect(find.byType(HabitBoard), findsOneWidget);
    expect(state.calendarShowsBoard, isTrue, reason: 'and it is remembered');

    await tester.tap(find.text(AppContent.calendarViewOverview));
    await tester.pumpAndSettle();
    expect(find.byType(HabitBoard), findsNothing);
  });
}
