import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/notification_content.dart';
import 'package:rewiremind/content/reminder_library.dart';
import 'package:rewiremind/models/day_phase.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/notification_prefs.dart';
import 'package:rewiremind/models/reminder.dart';
import 'package:rewiremind/notifications/notification_planner.dart';

/// The planner carries out the user's reminder list and makes no editorial
/// decisions of its own. What is asserted here is that it obeys exactly what
/// was configured — the right days, the right hour, the right words — and
/// nothing more.
void main() {
  const planner = NotificationPlanner();

  final wednesday = DateTime(2026, 9, 9);
  final saturday = DateTime(2026, 9, 12);
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
  final walk = habit('c', 'Walk 20 min');

  Reminder reminder({
    String id = 'r1',
    String text = 'Fresh page',
    TimeOfDayValue time = const TimeOfDayValue(8, 30),
    Set<int>? weekdays,
    bool enabled = true,
    bool skipWhenDone = true,
    bool withQuote = false,
  }) => Reminder(
    id: id,
    text: text,
    time: time,
    weekdays: weekdays ?? Reminder.everyDay,
    enabled: enabled,
    skipWhenDone: skipWhenDone,
    withQuote: withQuote,
  );

  DaySnapshot snapshot({
    DateTime? day,
    List<Habit>? scheduled,
    Set<String> completed = const {},
    int streak = 0,
    String name = 'Paras',
  }) => DaySnapshot(
    day: day ?? wednesday,
    scheduled: scheduled ?? [water, read, walk],
    completed: completed,
    streak: streak,
    name: name,
  );

  /// The daily catch-up is off unless a test is about it — otherwise every
  /// count in this file would silently include it.
  List<PlannedSend> planFrom(
    List<Reminder> reminders,
    DaySnapshot s, {
    bool enabled = true,
    bool catchUp = false,
    bool appendQuote = false,
    TimeOfDayValue catchUpTime = const TimeOfDayValue(20, 30),
    DateTime? now,
  }) => planner.planDay(
    prefs: NotificationPrefs(
      enabled: enabled,
      reminders: reminders,
      generalEnabled: true,
      catchUpEnabled: catchUp,
      catchUpTime: catchUpTime,
      appendQuote: appendQuote,
    ),
    snapshot: s,
    now: now ?? dawn,
  );

  group('the master switch', () {
    test('nothing is planned while notifications are off', () {
      expect(planFrom([reminder()], snapshot(), enabled: false), isEmpty);
    });

    test('an empty list sends nothing', () {
      expect(planFrom(const [], snapshot()), isEmpty);
    });
  });

  group('the user decides how many', () {
    test('five reminders produce five sends in a day', () {
      final many = [
        for (var i = 0; i < 5; i++)
          reminder(id: 'r$i', time: TimeOfDayValue(8 + i, 0)),
      ];
      final sends = planFrom(many, snapshot());

      expect(
        sends.length,
        5,
        reason: 'the app must not impose a ceiling of its own',
      );
      expect(sends.map((s) => s.reminderId).toSet().length, 5);
    });

    test('a switched-off reminder does not fire', () {
      final sends = planFrom([
        reminder(id: 'on'),
        reminder(id: 'off', enabled: false),
      ], snapshot());
      expect(sends.map((s) => s.reminderId), ['on']);
    });
  });

  group('the three kinds', () {
    test('a kind switched off sends nothing, and only that kind', () {
      final general = reminder(id: 'general');
      final forHabit = Reminder(
        id: 'habit',
        text: 'Water',
        time: const TimeOfDayValue(9, 0),
        habitId: water.id,
      );

      NotificationPrefs prefs({bool habits = true, bool generalOn = true}) =>
          NotificationPrefs(
            enabled: true,
            reminders: [general, forHabit],
            catchUpEnabled: false,
            habitRemindersEnabled: habits,
            generalEnabled: generalOn,
          );

      List<String> ids(NotificationPrefs p) => planner
          .planDay(prefs: p, snapshot: snapshot(), now: dawn)
          .map((s) => s.reminderId)
          .toList();

      expect(ids(prefs()), containsAll(['general', 'habit']));
      expect(ids(prefs(habits: false)), ['general']);
      expect(ids(prefs(generalOn: false)), ['habit']);
    });
  });

  group('days and times', () {
    test('a weekdays-only reminder skips Saturday', () {
      final weekdayOnly = reminder(weekdays: Reminder.weekdaysOnly);

      expect(planFrom([weekdayOnly], snapshot()), hasLength(1));
      expect(
        planFrom(
          [weekdayOnly],
          snapshot(day: saturday),
          now: DateTime(2026, 9, 12, 6),
        ),
        isEmpty,
      );
    });

    test('a single-day reminder fires only on that day', () {
      final fridayOnly = reminder(weekdays: const {5});
      expect(
        planFrom([fridayOnly], snapshot()),
        isEmpty,
        reason: 'the fixture day is a Wednesday',
      );
    });

    test('a time that has already passed today is not scheduled', () {
      final sends = planFrom(
        [reminder(time: const TimeOfDayValue(8, 30))],
        snapshot(),
        now: DateTime(2026, 9, 9, 15, 0),
      );
      expect(sends, isEmpty);
    });

    test('the send lands at exactly the configured minute', () {
      final sends = planFrom([
        reminder(time: const TimeOfDayValue(21, 45)),
      ], snapshot());
      expect(sends.single.at, DateTime(2026, 9, 9, 21, 45));
    });
  });

  group('skip if the day is done', () {
    test('a finished day silences a reminder that opted in', () {
      expect(
        planFrom([reminder()], snapshot(completed: {'a', 'b', 'c'})),
        isEmpty,
      );
    });

    test('but not one that opted out', () {
      expect(
        planFrom([
          reminder(skipWhenDone: false),
        ], snapshot(completed: {'a', 'b', 'c'})),
        hasLength(1),
        reason: 'the toggle is the user\'s call, not the app\'s',
      );
    });

    test('a partly done day still fires either way', () {
      expect(planFrom([reminder()], snapshot(completed: {'a'})), hasLength(1));
    });

    test('a day with nothing scheduled sends nothing', () {
      expect(
        planFrom([reminder()], snapshot(scheduled: const [])),
        isEmpty,
        reason: 'there is no habit to name and nothing to chase',
      );
    });
  });

  group('what the reminder says', () {
    test('the text is passed through exactly as written', () {
      final send = planFrom([
        reminder(text: 'Walk the dog 🐕'),
      ], snapshot()).single;

      expect(send.title, 'Walk the dog 🐕');
      expect(send.body, isEmpty, reason: 'no quote was asked for');
    });

    test('braces are never treated as anything special', () {
      // The token system is gone; whatever is typed is what arrives.
      final send = planFrom([
        reminder(text: 'Read {habit} pages'),
      ], snapshot()).single;

      expect(send.title, 'Read {habit} pages');
    });

    test('the quote is added only when asked for — once, for all of them', () {
      // The switch moved off the individual reminder and onto the screen: one
      // quote a day means one answer, not one answer per reminder.
      final without = planFrom([reminder()], snapshot()).single;
      final with_ = planFrom(
        [reminder()],
        snapshot(),
        appendQuote: true,
      ).single;

      expect(without.body, isEmpty);
      expect(with_.body, NotificationContent.quoteFor(wednesday));
    });

    test(
      'the habit placeholder never survives into a preset the user sees',
      () {
        // Habit presets carry a placeholder, but the picker substitutes it
        // before the wording reaches the editor. Everything else must be plain.
        for (final category in ReminderLibrary.categories) {
          for (final preset in category.presets) {
            expect(preset.text, isNot(contains('{')), reason: preset.text);
          }
        }
        for (final preset in ReminderLibrary.starters) {
          expect(preset.text, isNot(contains('{')), reason: preset.text);
        }
      },
    );

    test('habit presets resolve to a plain sentence', () {
      for (final preset in ReminderLibrary.habitPresets) {
        final resolved = NotificationContent.forHabit(
          preset.text,
          'Read 10 pages',
        );
        expect(resolved, isNot(contains('{')), reason: preset.text);
        expect(resolved, isNotEmpty);
      }
    });
  });

  group('the resulting notification', () {
    test('carries the phase of the hour it arrives at', () {
      final morning = planFrom([
        reminder(time: const TimeOfDayValue(8, 30)),
      ], snapshot()).single;
      final night = planFrom([
        reminder(time: const TimeOfDayValue(21, 0)),
      ], snapshot()).single;

      expect(morning.phase, DayPhase.earlyMorning);
      expect(night.phase, DayPhase.night);
    });

    test('only a habit reminder offers Mark done, and only while open', () {
      final forWater = Reminder(
        id: 'w',
        text: 'Water',
        time: const TimeOfDayValue(9, 0),
        habitId: water.id,
        skipWhenDone: false,
      );
      final open = planFrom([forWater], snapshot()).single;
      expect(open.canMarkDone, isTrue);
      expect(open.kind, SendKind.habit);
      expect(open.habitId, water.id);
      expect(open.label, water.name, reason: 'the habit, beside the app name');

      expect(
        planFrom([forWater], snapshot(completed: {'a'})).single.canMarkDone,
        isFalse,
        reason: 'nothing to mark once it is done',
      );
      // No button that ticks everything: a general reminder has none.
      expect(planFrom([reminder()], snapshot()).single.canMarkDone, isFalse);
    });

    test('the evening send lists what is left, with the day so far', () {
      final send = planner
          .planDay(
            prefs: const NotificationPrefs(enabled: true),
            snapshot: snapshot(completed: {'a'}),
            now: dawn,
          )
          .single;
      expect(send.kind, SendKind.nudge);
      expect(send.lines, ['Read 10 pages', 'Walk 20 min']);
      expect((send.done, send.total), (1, 3));
      expect(send.label, NotificationContent.nudgeLabel);
    });
  });

  group('scheduling across days', () {
    test('ids are unique per reminder per day, so nothing overwrites', () {
      final sends = planner.plan(
        prefs: NotificationPrefs(
          enabled: true,
          catchUpEnabled: false,
          generalEnabled: true,
          reminders: [
            reminder(id: 'a', time: const TimeOfDayValue(9, 0)),
            reminder(id: 'b', time: const TimeOfDayValue(20, 0)),
          ],
        ),
        from: dawn,
        days: 3,
        snapshotFor: (d) => snapshot(day: d),
      );

      final ids = sends.map((s) => s.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'a duplicate id silently replaces another notification',
      );
      expect(sends, hasLength(6));
    });

    test('sends come back in chronological order', () {
      final sends = planner.plan(
        prefs: NotificationPrefs(
          enabled: true,
          catchUpEnabled: false,
          generalEnabled: true,
          reminders: [
            reminder(id: 'late', time: const TimeOfDayValue(21, 0)),
            reminder(id: 'early', time: const TimeOfDayValue(9, 0)),
          ],
        ),
        from: dawn,
        days: 2,
        snapshotFor: (d) => snapshot(day: d),
      );

      for (var i = 1; i < sends.length; i++) {
        expect(sends[i].at.isBefore(sends[i - 1].at), isFalse);
      }
    });

    test('every planned send is in the future', () {
      final noon = DateTime(2026, 9, 9, 12, 30);
      final sends = planner.plan(
        prefs: NotificationPrefs(
          enabled: true,
          catchUpEnabled: false,
          generalEnabled: true,
          reminders: [reminder()],
        ),
        from: noon,
        days: 3,
        snapshotFor: (d) => snapshot(day: d),
      );

      for (final send in sends) {
        expect(send.at.isAfter(noon), isTrue, reason: '$send');
      }
    });
  });

  group('reminders survive a reload', () {
    test('a round trip through JSON keeps every field', () {
      final original = reminder(
        id: 'keep-me',
        text: 'Evening walk',
        time: const TimeOfDayValue(19, 15),
        weekdays: const {1, 3, 5},
        skipWhenDone: false,
        withQuote: true,
      );

      final back = Reminder.fromJson(original.toJson());

      expect(back.id, 'keep-me');
      expect(back.text, 'Evening walk');
      expect(back.time, const TimeOfDayValue(19, 15));
      expect(back.weekdays, {1, 3, 5});
      expect(back.skipWhenDone, isFalse);
      expect(back.withQuote, isTrue);
    });

    test('the whole list round trips', () {
      final prefs = NotificationPrefs(
        enabled: true,
        reminders: [
          reminder(id: 'a'),
          reminder(id: 'b'),
        ],
      );
      final back = NotificationPrefs.fromJson(prefs.toJson());

      expect(back.enabled, isTrue);
      expect(back.reminders.map((r) => r.id), ['a', 'b']);
    });
  });

  group('the daily catch-up', () {
    test('one notification, never a pair', () {
      // An unlogged day and a streak about to break are the same fact, so a
      // long streak must not produce a second send alongside the first.
      for (final streak in [0, 1, 2, 3, 12]) {
        final sends = planFrom(
          const [],
          snapshot(completed: {'a'}, streak: streak),
          catchUp: true,
        );
        expect(sends, hasLength(1), reason: 'streak $streak');
        expect(sends.single.reminderId, NotificationPlanner.catchUpId);
      }
    });

    test('the wording changes with the streak, the count does not', () {
      final noStreak = planFrom(
        const [],
        snapshot(completed: {'a'}, streak: 0),
        catchUp: true,
      ).single;
      final onAStreak = planFrom(
        const [],
        snapshot(completed: {'a'}, streak: 12),
        catchUp: true,
      ).single;

      expect(noStreak.title, contains('habits left'));
      expect(
        onAStreak.title,
        contains('12-day streak'),
        reason: 'the streak is the hook once there is one to lose',
      );
      expect(noStreak.title, isNot(onAStreak.title));
    });

    test('a two-day streak already reads as a streak', () {
      final send = planFrom(
        const [],
        snapshot(completed: {'a'}, streak: 2),
        catchUp: true,
      ).single;
      expect(send.title, contains('2-day streak'));
    });

    test('silent once the day is fully logged', () {
      expect(
        planFrom(const [], snapshot(completed: {'a', 'b', 'c'}), catchUp: true),
        isEmpty,
      );
    });

    test('silent when switched off', () {
      expect(planFrom(const [], snapshot(), catchUp: false), isEmpty);
    });

    test('honours its own time, not a reminder time', () {
      final send = planFrom(
        const [],
        snapshot(),
        catchUp: true,
        catchUpTime: const TimeOfDayValue(19, 15),
      ).single;
      expect(send.at, DateTime(2026, 9, 9, 19, 15));
    });

    test("fires alongside the user's own reminders without replacing them", () {
      final sends = planFrom(
        [reminder(id: 'mine', time: const TimeOfDayValue(9, 0))],
        snapshot(),
        catchUp: true,
      );
      expect(
        sends.map((s) => s.reminderId),
        containsAll(['mine', NotificationPlanner.catchUpId]),
      );
    });
  });

  group('reminders attached to one habit', () {
    Reminder forHabit(String habitId, {String text = 'Time for it'}) =>
        Reminder(
          id: 'h1',
          habitId: habitId,
          text: text,
          time: const TimeOfDayValue(9, 0),
        );

    test('goes quiet once its own habit is ticked', () {
      expect(planFrom([forHabit('b')], snapshot(completed: {'b'})), isEmpty);
    });

    test(
      'still fires while its habit is outstanding, even if others are done',
      () {
        expect(
          planFrom([forHabit('b')], snapshot(completed: {'a', 'c'})),
          hasLength(1),
          reason: "the rest of the day is not this reminder's business",
        );
      },
    );

    test('is silent on days its habit is not scheduled', () {
      expect(planFrom([forHabit('b')], snapshot(scheduled: [water])), isEmpty);
    });

    test('a habit that no longer exists produces nothing', () {
      expect(planFrom([forHabit('gone')], snapshot()), isEmpty);
    });

    test('the scope survives a reload', () {
      final back = Reminder.fromJson(forHabit('b').toJson());
      expect(back.habitId, 'b');
      expect(back.isForHabit, isTrue);
      expect(back.text, 'Time for it');
    });

    test('a general reminder has no habit', () {
      final back = Reminder.fromJson(reminder().toJson());
      expect(back.habitId, isNull);
      expect(back.isForHabit, isFalse);
    });

    test('every habit preset names the habit', () {
      for (final preset in ReminderLibrary.habitPresets) {
        expect(
          preset.text,
          contains(NotificationContent.habitPlaceholder),
          reason: 'a habit preset that never says the habit is a general one',
        );
      }
    });
  });

  group('the clock reads as a clock', () {
    test('times are twelve-hour with a meridiem', () {
      expect(const TimeOfDayValue(8, 30).format(), '8:30 AM');
      expect(const TimeOfDayValue(20, 5).format(), '8:05 PM');
      expect(const TimeOfDayValue(0, 0).format(), '12:00 AM');
      expect(const TimeOfDayValue(12, 0).format(), '12:00 PM');
      expect(const TimeOfDayValue(23, 59).format(), '11:59 PM');
    });

    test('the repeat label reads in plain English', () {
      expect(reminder().scheduleLabel, 'Every day');
      expect(
        reminder(weekdays: Reminder.weekdaysOnly).scheduleLabel,
        'Weekdays',
      );
      expect(
        reminder(weekdays: Reminder.weekendsOnly).scheduleLabel,
        'Weekends',
      );
      expect(
        reminder(weekdays: const {1, 3, 5}).scheduleLabel,
        'Mon, Wed, Fri',
      );
    });
  });
}
