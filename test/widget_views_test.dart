import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/models/progress_range.dart';
import 'package:rewiremind/models/stats.dart';
import 'package:rewiremind/notifications/widget_views.dart';
import 'package:rewiremind/screens/widgets_screen.dart';
import 'package:rewiremind/widgets/widget_previews.dart';

import 'helpers.dart';

/// The checklist, week and month widgets read JSON that Dart writes and
/// Kotlin reads back against the real clock. Nothing links the two sides but
/// the shape of that JSON and four status letters, so both are pinned here.
void main() {
  test('the checklist carries today and the six days after it', () async {
    final state = await emptyState();
    final walk = await state.addHabit(
      name: 'Walk',
      iconKey: 'walk',
      target: 1,
      unit: 'times',
    );
    await state.addHabit(
      name: 'Read',
      iconKey: 'book',
      target: 1,
      unit: 'times',
    );
    await state.setValue(walk, state.today, 1);

    final json = jsonDecode(state.widgetList()) as Map<String, dynamic>;
    expect(json['habits'], 1);
    final days = json['days'] as Map<String, dynamic>;
    expect(days, hasLength(WidgetViews.listDays));

    final today = days[dayKey(state.today)] as List<dynamic>;
    expect(today, [
      ['Walk', 1],
      ['Read', 0],
    ]);

    // Tomorrow's list is there before tomorrow, and nothing on it is done.
    final t = state.today;
    final tomorrow = days[dayKey(DateTime(t.year, t.month, t.day + 1))] as List;
    expect(tomorrow.every((e) => (e as List)[1] == 0), isTrue);
  });

  test('no habits says so, rather than an empty day', () async {
    final state = await emptyState();
    final json = jsonDecode(state.widgetList()) as Map<String, dynamic>;
    expect(json['habits'], 0);
  });

  test('the calendar runs from the first of last month to today', () async {
    final state = await seededState();
    final json = jsonDecode(state.widgetCalendar()) as Map<String, dynamic>;
    final t = state.today;
    final from = DateTime(t.year, t.month - 1, 1);

    expect(json['from'], dayKey(from));
    expect(json['stamp'], dayKey(t));

    final codes = json['s'] as String;
    final days =
        DateTime.utc(
          t.year,
          t.month,
          t.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
        1;
    expect(codes, hasLength(days));
    // The last letter is today, and it agrees with the app's own status.
    expect(codes[codes.length - 1], WidgetViews.code(state.dayStatus(t)));
  });

  test('the status letters are the ones the Kotlin reads', () {
    final kotlin = File(
      'android/app/src/main/kotlin/com/parasjain/rewiremind/'
      'RewireMindViewWidgets.kt',
    ).readAsStringSync();
    for (final (name, status) in [
      ('ALL', DayStatus.all),
      ('SOME', DayStatus.some),
      ('NONE', DayStatus.none),
      ('EMPTY', DayStatus.empty),
    ]) {
      expect(
        kotlin,
        contains("const val $name = '${WidgetViews.code(status)}'"),
        reason: '$name means something different on each side',
      );
    }
  });

  test('every change reaches the widgets', () async {
    final state = await emptyState();
    final habit = await state.addHabit(
      name: 'Stretch',
      iconKey: 'yoga',
      target: 1,
      unit: 'times',
    );
    await state.setValue(habit, state.today, 1);
    await state.refreshHomeWidget();
    expect(state.homeWidget.lastList, contains('["Stretch",1]'));
    expect(state.homeWidget.lastCalendar, isNotNull);
  });

  group('the Progress banner', () {
    test('does not praise an empty week', () {
      final banner = AppContent.progressBanner(
        ProgressRange.week,
        completed: 0,
        scheduled: 0,
        percent: 0,
      );
      expect(banner.title, isNot(contains('Great')));
      expect(banner.line, isNotNull);
    });

    test('a week with habits but no ticks is a fresh start', () {
      final banner = AppContent.progressBanner(
        ProgressRange.week,
        completed: 0,
        scheduled: 12,
        percent: 0,
      );
      expect(banner.title, 'A fresh start');
    });

    test('praise is kept for weeks that earned it', () {
      expect(
        AppContent.progressBanner(
          ProgressRange.week,
          completed: 2,
          scheduled: 20,
          percent: 10,
        ).title,
        isNot(contains('Great')),
      );
      expect(
        AppContent.progressBanner(
          ProgressRange.week,
          completed: 18,
          scheduled: 20,
          percent: 90,
        ).title,
        AppContent.progressFor(ProgressRange.week).bannerTitle,
      );
    });
  });

  testWidgets('the gallery shows each view as it will look', (tester) async {
    final state = await seededState();
    await pumpAppWith(tester, state);
    WidgetsScreen.open(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();

    expect(find.text(AppContent.widgetTitle), findsOneWidget);
    expect(find.byType(MascotPreview), findsOneWidget);

    await tester.tap(find.text(AppContent.widgetViewName('list')));
    await tester.pumpAndSettle();
    expect(find.byType(ChecklistPreview), findsOneWidget);
    // Today's real habits, not a made-up list.
    final first = state.scheduledOn(state.today).first.name;
    expect(
      find.descendant(
        of: find.byType(ChecklistPreview),
        matching: find.text(first),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(AppContent.widgetViewName('week')));
    await tester.pumpAndSettle();
    expect(find.byType(WeekPreview), findsOneWidget);

    await tester.tap(find.text(AppContent.widgetViewName('month')));
    await tester.pumpAndSettle();
    expect(find.byType(MonthPreview), findsOneWidget);
    expect(find.text('3×2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the gallery lays out on a small phone too', (tester) async {
    final state = await seededState();
    await pumpAppWith(tester, state);
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    await tester.pumpAndSettle();
    WidgetsScreen.open(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    for (final view in ['mascot', 'list', 'week', 'month']) {
      await tester.tap(find.text(AppContent.widgetViewName(view)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: view);
    }
  });
}
