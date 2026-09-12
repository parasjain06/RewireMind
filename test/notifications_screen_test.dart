import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/notification_content.dart';
import 'package:rewiremind/models/reminder.dart';
import 'package:rewiremind/screens/notifications_screen.dart';
import 'package:rewiremind/screens/reminder_editor_sheet.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/models/habit.dart';

import 'helpers.dart';

/// The reminder list is the whole feature's surface: adding, editing, timing
/// and deleting all happen here, and every one of them has to reach the
/// schedule rather than only the screen.
void main() {
  /// A window tall enough to hold the whole settings screen.
  ///
  /// It reads top to bottom in these tests, and a lazy list does not build
  /// what is below the fold — so on a phone-sized viewport a finder fails for
  /// a row that is merely further down, which says nothing about whether the
  /// screen is right.
  void tallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openSettings(WidgetTester tester) async {
    tallWindow(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
  }

  /// Enables reminders the way a granted permission prompt would, since the
  /// prompt itself cannot run in a test.
  /// The daily catch-up is off unless a test is about it — it is a send in its
  /// own right, and otherwise every count here would silently include it.
  Future<AppState> enabledState({
    List<Reminder>? reminders,
    bool catchUp = false,
  }) async {
    final state = await seededState();
    await state.setNotifyPrefs(
      state.notifyPrefs.copyWith(
        enabled: true,
        reminders: reminders ?? [],
        catchUpEnabled: catchUp,
        // The challenge shares the catch-up's slot; off with it here.
        challengeEnabled: catchUp,
        generalEnabled: true,
      ),
    );
    return state;
  }

  Reminder reminder({
    String id = 'r1',
    String text = 'Fresh page',
    TimeOfDayValue time = const TimeOfDayValue(8, 30),
  }) => Reminder(id: id, text: text, time: time);

  testWidgets('the Profile row opens the reminders screen', (tester) async {
    await pumpSeededApp(tester);
    await openSettings(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh install is off and shows no reminder list', (
    tester,
  ) async {
    final state = await seededState();
    await pumpAppWith(tester, state);
    await openSettings(tester);

    expect(
      state.notifyPrefs.enabled,
      isFalse,
      reason: 'a new install must be silent until asked',
    );
    expect(find.text(NotificationContent.addLabel), findsNothing);
  });

  testWidgets('turning reminders on reveals the list and the add button', (
    tester,
  ) async {
    final state = await enabledState(reminders: [reminder()]);
    await pumpAppWith(tester, state);
    await openSettings(tester);

    expect(find.text('Fresh page'), findsOneWidget);
    expect(find.text(NotificationContent.addLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with notifications on, the three kinds each have a switch', (
    tester,
  ) async {
    final state = await enabledState();
    await pumpAppWith(tester, state);
    await openSettings(tester);

    expect(find.text(NotificationContent.kindHabitTitle), findsOneWidget);
    expect(find.text(NotificationContent.catchUpTitleLabel), findsOneWidget);
    expect(find.text(NotificationContent.generalTitle), findsOneWidget);
    // And the way to add one is under the kind it belongs to.
    expect(find.text(NotificationContent.addLabel), findsOneWidget);
  });

  testWidgets('turning a kind off hides its reminders and keeps them', (
    tester,
  ) async {
    final state = await enabledState(reminders: [reminder()]);
    await pumpAppWith(tester, state);
    await openSettings(tester);
    expect(find.text('Fresh page'), findsOneWidget);

    // The general kind's switch: the one in the row that names it.
    final row = find.ancestor(
      of: find.text(NotificationContent.generalTitle),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(state.notifyPrefs.generalEnabled, isFalse);
    expect(find.text('Fresh page'), findsNothing);
    expect(state.notifyPrefs.active, isEmpty, reason: 'nothing will be sent');
    expect(
      state.notifyPrefs.reminders,
      hasLength(1),
      reason: 'off is not deleted: it comes back as it was',
    );
  });

  testWidgets('times are shown with AM and PM, never 24-hour', (tester) async {
    final state = await enabledState(
      reminders: [
        reminder(id: 'a', time: const TimeOfDayValue(8, 30)),
        reminder(id: 'b', text: 'Evening', time: const TimeOfDayValue(20, 30)),
      ],
    );
    await pumpAppWith(tester, state);
    await openSettings(tester);

    expect(find.text('8:30 AM'), findsOneWidget);
    expect(find.text('8:30 PM'), findsOneWidget);
    expect(
      find.text('20:30'),
      findsNothing,
      reason: 'a reminder list of 24-hour times reads like a timetable',
    );
  });

  testWidgets('adding opens the preset picker, and a preset opens the editor', (
    tester,
  ) async {
    final state = await enabledState();
    await pumpAppWith(tester, state);
    await openSettings(tester);

    await tester.tap(find.text(NotificationContent.addLabel));
    await tester.pumpAndSettle();
    expect(find.text(NotificationContent.presetsTitle), findsOneWidget);

    // "Write my own" is the escape hatch from the presets.
    await tester.tap(find.text(NotificationContent.customLabel));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderEditorSheet), findsOneWidget);
    expect(find.text(NotificationContent.editorNewTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a reminder opens it for editing', (tester) async {
    final state = await enabledState(reminders: [reminder()]);
    await pumpAppWith(tester, state);
    await openSettings(tester);

    await tester.tap(find.text('Fresh page'));
    await tester.pumpAndSettle();

    expect(find.text(NotificationContent.editorEditTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the editor is a single field, previewed live', (tester) async {
    final state = await enabledState(reminders: [reminder(text: 'Walk time')]);
    await pumpAppWith(tester, state);
    await openSettings(tester);

    await tester.tap(find.text('Walk time'));
    await tester.pumpAndSettle();

    // One text field, not a title and a body.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(NotificationContent.editorTextLabel), findsOneWidget);
    // The preview echoes it back.
    expect(find.text('Walk time'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching a reminder off removes it from the schedule', (
    tester,
  ) async {
    final state = await enabledState(reminders: [reminder()]);

    expect(state.planNotifications(), isNotEmpty);

    await state.saveReminder(
      state.notifyPrefs.reminders.single.copyWith(enabled: false),
    );

    expect(
      state.planNotifications(),
      isEmpty,
      reason: 'the switch has to reach the schedule, not just the row',
    );
  });

  testWidgets('deleting a reminder clears its sends', (tester) async {
    final state = await enabledState(reminders: [reminder()]);
    expect(state.planNotifications(), isNotEmpty);

    await state.deleteReminder('r1');

    expect(state.notifyPrefs.reminders, isEmpty);
    expect(state.planNotifications(), isEmpty);
  });

  testWidgets('the user decides how many; the app imposes no ceiling', (
    tester,
  ) async {
    final state = await enabledState(
      reminders: [
        for (var i = 0; i < 6; i++)
          reminder(id: 'r$i', time: TimeOfDayValue(8 + i, 0)),
      ],
    );

    final today = state.today;
    final todaysSends = state
        .planNotifications(from: DateTime(today.year, today.month, today.day))
        .where((s) => s.at.day == today.day)
        .length;

    expect(todaysSends, 6);
  });

  testWidgets('reminders survive a reload', (tester) async {
    await enabledState(
      reminders: [
        reminder(
          id: 'keep',
          text: 'Evening',
          time: const TimeOfDayValue(19, 15),
        ),
      ],
    );

    final reloaded = await reopen();
    expect(reloaded.notifyPrefs.enabled, isTrue);
    expect(reloaded.notifyPrefs.reminders.single.text, 'Evening');
    expect(
      reloaded.notifyPrefs.reminders.single.time,
      const TimeOfDayValue(19, 15),
    );
  });

  testWidgets('the list reads as a day, earliest first', (tester) async {
    final state = await enabledState(
      reminders: [
        reminder(id: 'late', text: 'Night', time: const TimeOfDayValue(21, 0)),
        reminder(id: 'early', text: 'Dawn', time: const TimeOfDayValue(7, 0)),
      ],
    );

    expect(state.notifyPrefs.byTime.map((r) => r.text), ['Dawn', 'Night']);

    await pumpAppWith(tester, state);
    await openSettings(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the button on a reminder logs one step, not the day', (
    tester,
  ) async {
    final state = await seededState();
    final today = state.today;
    final open = state
        .scheduledOn(today)
        .where((h) => !state.isComplete(h, today))
        .toList();
    expect(open.length, greaterThan(1), reason: 'the fixture needs two open');

    final measured = open.firstWhere((h) => !h.isBinary);
    final before = state.valueOf(measured.id, today);

    expect(
      await state.logStepFromNotification(measured.id),
      before + measured.step,
      reason: 'one glass, not all eight',
    );
    expect(state.valueOf(measured.id, today), before + measured.step);
    expect(
      state.isComplete(measured, today),
      isFalse,
      reason: 'a step is not the day, unless the day is one step',
    );
    // The other habits are untouched by it.
    for (final other in open.where((h) => h.id != measured.id)) {
      expect(state.isComplete(other, today), isFalse);
    }

    // A daily tick is one step, so its button finishes it.
    final binary = open.firstWhere((h) => h.isBinary, orElse: () => measured);
    if (binary.isBinary) {
      await state.logStepFromNotification(binary.id);
      expect(state.isComplete(binary, today), isTrue);
      expect(
        await state.logStepFromNotification(binary.id),
        isNull,
        reason: 'and pressing it again does nothing',
      );
    }
  });

  test('one step of a habit is a glass, a page, or a round few minutes', () {
    Habit of(double target) => Habit(
      id: 't',
      name: 't',
      iconKey: 'walk',
      target: target,
      unit: '',
      createdAt: DateTime(2026),
    );

    expect(of(1).step, 1, reason: 'a daily tick is all of itself');
    expect(of(8).step, 1, reason: 'eight glasses go up one at a time');
    expect(of(10).step, 1);
    expect(of(30).step, 10, reason: 'thirty minutes in three');
    expect(of(60).step, 15);
    expect(of(2.5).step, 0.5);

    Habit glasses(double target) => Habit(
      id: 'g',
      name: 'Water',
      iconKey: 'water',
      target: target,
      unit: 'glasses',
      createdAt: DateTime(2026),
    );
    expect(
      glasses(8).stepLabel,
      '1 glass',
      reason: 'a button that says "+1 glasses" was written by a machine',
    );
    expect(glasses(2).stepLabel, '1 glass');
  });

  group('the daily catch-up', () {
    testWidgets('has its own card and its own time', (tester) async {
      final state = await enabledState(catchUp: true);
      await pumpAppWith(tester, state);
      await openSettings(tester);

      expect(find.text(NotificationContent.catchUpTitleLabel), findsOneWidget);
      expect(find.text('8:30 PM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('produces exactly one send however long the streak is', (
      tester,
    ) async {
      final state = await enabledState(catchUp: true);

      final today = state.today;
      // Planned from first light rather than from the wall clock: run this
      // after 8:30 PM and today's catch-up is legitimately in the past, so
      // the real clock would decide whether the test passed.
      final todays = state
          .planNotifications(from: today.add(const Duration(hours: 1)))
          .where((s) => s.at.day == today.day)
          .toList();

      expect(
        todays,
        hasLength(1),
        reason: 'an unlogged day and a streak at risk are the same fact',
      );
    });

    testWidgets('switching it off removes it from the schedule', (
      tester,
    ) async {
      final state = await enabledState(catchUp: true);
      expect(state.planNotifications(), isNotEmpty);

      await state.setCatchUpEnabled(false);
      expect(state.planNotifications(), isEmpty);
    });

    testWidgets('its time is editable and persists', (tester) async {
      final state = await enabledState(catchUp: true);
      await state.setCatchUpTime(const TimeOfDayValue(21, 15));

      final reloaded = await reopen();
      expect(reloaded.notifyPrefs.catchUpTime, const TimeOfDayValue(21, 15));
      expect(reloaded.notifyPrefs.catchUpEnabled, isTrue);
    });
  });

  group('reminders attached to a habit', () {
    testWidgets('the habit screen offers its own reminders', (tester) async {
      final state = await enabledState();
      await pumpAppWith(tester, state);

      await tester.tap(find.text('Drink 2L water'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(NotificationContent.habitRemindersEmpty),
        150,
      );
      expect(
        find.text(NotificationContent.habitRemindersEmpty),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a habit reminder is listed on its habit, not on the others', (
      tester,
    ) async {
      final state = await enabledState();
      final habits = state.habits;

      await state.saveReminder(
        Reminder(
          id: 'scoped',
          habitId: habits.first.id,
          text: 'Time for water',
          time: const TimeOfDayValue(9, 0),
        ),
      );

      expect(state.notifyPrefs.forHabit(habits.first.id), hasLength(1));
      expect(state.notifyPrefs.forHabit(habits[1].id), isEmpty);
      expect(
        state.notifyPrefs.general,
        isEmpty,
        reason: 'a scoped reminder is not a general one',
      );
    });

    testWidgets('deleting the habit deletes its reminders', (tester) async {
      final state = await enabledState();
      final habit = state.habits.first;

      await state.saveReminder(
        Reminder(
          id: 'scoped',
          habitId: habit.id,
          text: 'Time for water',
          time: const TimeOfDayValue(9, 0),
        ),
      );
      expect(state.notifyPrefs.reminders, hasLength(1));

      await state.deleteHabit(habit);

      expect(
        state.notifyPrefs.reminders,
        isEmpty,
        reason: 'an orphaned reminder would never fire but would still show',
      );

      final reloaded = await reopen();
      expect(reloaded.notifyPrefs.reminders, isEmpty);
    });
  });

  testWidgets('a finished day silences reminders that opted in', (
    tester,
  ) async {
    final state = await enabledState(reminders: [reminder()]);
    await keepDay(state, state.today);

    final today = state.today;
    final todaysSends = state
        .planNotifications()
        .where((s) => s.at.day == today.day)
        .toList();

    expect(todaysSends, isEmpty);
  });
}
