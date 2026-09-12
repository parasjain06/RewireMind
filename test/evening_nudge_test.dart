import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/notification_content.dart';
import 'package:rewiremind/content/reminder_library.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/notification_prefs.dart';
import 'package:rewiremind/models/reminder.dart';
import 'package:rewiremind/notifications/notification_planner.dart';
import 'package:rewiremind/screens/notifications_screen.dart';

import 'helpers.dart';

/// The daily catch-up and the 21-day challenge share one evening send. Asked
/// for plainly: "only one notification is required in a day".
void main() {
  const planner = NotificationPlanner();
  final wednesday = DateTime(2026, 9, 9);
  final dawn = DateTime(2026, 9, 9, 6, 0);

  Habit habit(String id, String name) => Habit(
    id: id,
    name: name,
    iconKey: 'water',
    target: 1,
    unit: 'time',
    createdAt: DateTime(2026, 1, 1),
  );

  final water = habit('a', 'Drink 2L water');
  final read = habit('b', 'Read 10 pages');

  DaySnapshot day({int? challengeDay, Set<String> completed = const {}}) =>
      DaySnapshot(
        day: wednesday,
        scheduled: [water, read],
        completed: completed,
        streak: 4,
        challengeDay: challengeDay,
      );

  List<PlannedSend> plan(
    DaySnapshot snapshot, {
    bool catchUp = true,
    bool challenge = true,
  }) => planner.planDay(
    prefs: NotificationPrefs(
      enabled: true,
      catchUpEnabled: catchUp,
      challengeEnabled: challenge,
    ),
    snapshot: snapshot,
    now: dawn,
  );

  test('catch-up and challenge together are still one send', () {
    final sends = plan(day(challengeDay: 9));
    expect(sends, hasLength(1));
    expect(sends.single.title, NotificationContent.challengeTitle(9, 21));
    expect(sends.single.body, contains('2 habits left'));
  });

  test('without a challenge running it is the plain catch-up', () {
    final sends = plan(day());
    expect(sends, hasLength(1));
    expect(
      sends.single.title,
      NotificationContent.catchUpTitle(streak: 4, pending: 2),
    );
  });

  test('the challenge nudge works with the catch-up off', () {
    expect(plan(day(challengeDay: 3), catchUp: false), hasLength(1));
    // And with no challenge running there is nothing to say.
    expect(plan(day(), catchUp: false), isEmpty);
  });

  test('the challenge off leaves the catch-up in its own words', () {
    final sends = plan(day(challengeDay: 9), challenge: false);
    expect(sends.single.title, isNot(contains('Challenge')));
  });

  test('a finished day gets nothing, challenge or not', () {
    expect(plan(day(challengeDay: 9, completed: {'a', 'b'})), isEmpty);
  });

  test('the last day says so', () {
    expect(NotificationContent.challengeTitle(21, 21), contains('Last day'));
  });

  group('general reminders', () {
    test('start off', () {
      expect(const NotificationPrefs().generalEnabled, isFalse);
    });

    test('turning notifications on adds none', () async {
      final state = await seededState();
      await state.setNotifyPrefs(state.notifyPrefs.copyWith(enabled: true));
      expect(state.notifyPrefs.reminders, isEmpty);
      expect(state.notifyPrefs.generalEnabled, isFalse);
    });

    test('the two added automatically before are taken back', () {
      // Saved by the version that added them, which knew nothing about the
      // challenge switch.
      final old = {
        'enabled': true,
        'generalEnabled': true,
        'reminders': [
          for (final (i, s) in ReminderLibrary.starters.indexed)
            Reminder(
              id: 's$i',
              text: s.text,
              time: TimeOfDayValue(8 + i, 30),
            ).toJson(),
        ],
      };
      final back = NotificationPrefs.fromJson(old);
      expect(back.reminders, isEmpty);
      expect(back.generalEnabled, isFalse);
      expect(back.challengeEnabled, isTrue);
    });

    test('but anything written by hand stays, and stays on', () {
      final old = {
        'enabled': true,
        'generalEnabled': true,
        'reminders': [
          const Reminder(
            id: 'mine',
            text: 'Stretch',
            time: TimeOfDayValue(7, 0),
          ).toJson(),
          Reminder(
            id: 's0',
            text: ReminderLibrary.starters.first.text,
            time: const TimeOfDayValue(8, 30),
          ).toJson(),
        ],
      };
      final back = NotificationPrefs.fromJson(old);
      expect(back.reminders.map((r) => r.id), ['mine']);
      expect(back.generalEnabled, isTrue);
    });

    test('a choice made since is kept as it is', () {
      final now = const NotificationPrefs(
        enabled: true,
        generalEnabled: true,
        reminders: [
          Reminder(id: 'x', text: 'Fresh page 🌅', time: TimeOfDayValue(8, 0)),
        ],
      ).toJson();
      final back = NotificationPrefs.fromJson(now);
      expect(back.reminders, hasLength(1));
      expect(back.generalEnabled, isTrue);
    });
  });

  testWidgets('the page puts both in one card with one time', (tester) async {
    final state = await seededState();
    await state.setNotifyPrefs(state.notifyPrefs.copyWith(enabled: true));
    await pumpAppWith(tester, state);
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpAndSettle();
    NotificationsScreen.open(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();

    expect(find.text(NotificationContent.catchUpTitleLabel), findsOneWidget);
    expect(find.text(NotificationContent.challengeToggleTitle), findsOneWidget);
    expect(find.text(NotificationContent.oneADay), findsOneWidget);
    expect(find.text('8:30 PM'), findsOneWidget);

    final row = find.ancestor(
      of: find.text(NotificationContent.challengeToggleTitle),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(state.notifyPrefs.challengeEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
