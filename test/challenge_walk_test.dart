import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/notifications/path_sound.dart';
import 'package:rewiremind/screens/roadmap_screen.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/theme/app_theme.dart';

import 'helpers.dart';

/// The once-a-day walk up the 21-day path.
///
/// Keeping a day earns the next stop, and the first time the app is opened on
/// the following day the trail climbs to it. Everything about when that fires
/// is decided here, because the failure modes are all about timing: firing on
/// the day somebody starts (a celebration of pressing a button), firing twice
/// in a day (an animation people learn to dread), or firing after a missed day
/// (congratulating somebody for breaking their run).
void main() {
  /// A habit kept on every one of [keptDays] days back from today.
  ///
  /// The challenge began [startedDaysAgo] days ago, so "started yesterday and
  /// kept it" is startedDaysAgo: 1, keptDays: [1].
  Future<AppState> path({
    required int startedDaysAgo,
    required List<int> keptDays,
    int? seenStop,
    // How long the habit has existed, if longer than the challenge.
    int? habitDaysAgo,
  }) async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    disableQuoteAutoAdvance();
    SharedPreferences.setMockInitialValues({});

    final storage = await RewireMindStorage.open();
    final now = dateOnly(DateTime.now());
    final start = now.subtract(Duration(days: startedDaysAgo));

    await storage.saveHabits([
      Habit(
        id: 'h',
        name: 'Read',
        iconKey: 'book',
        target: 1,
        unit: '',
        createdAt: now.subtract(Duration(days: habitDaysAgo ?? startedDaysAgo)),
        sortOrder: 0,
      ),
    ]);
    await storage.saveLogs({
      'h': {
        for (final back in keptDays)
          dayKey(now.subtract(Duration(days: back))): 1.0,
      },
    });
    await storage.setChallengeStartedOn(start);
    await storage.setChallengeSeenStop(seenStop ?? 0);
    await storage.markSeeded();

    final state = AppState(storage);
    await state.load();
    return state;
  }

  Future<void> pumpPath(
    WidgetTester tester,
    AppState state, {
    int? walkFrom,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: RewireMindTheme.byId('forest').toThemeData(),
          home: RoadmapScreen(walkFrom: walkFrom),
        ),
      ),
    );
    await tester.pump();
  }

  /// Runs the clock past the intro, the pause and the climb.
  ///
  /// Frame by frame rather than `pumpAndSettle`: the path's ambient loop —
  /// drifting leaves, the ring around today — never stops, so there is no
  /// still state to settle into.
  Future<void> letTheWalkFinish(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('the walk lands, says where, and rings once', (tester) async {
    final state = await path(startedDaysAgo: 1, keptDays: [1], seenStop: 1);
    expect(state.challengeStop, 2);

    final travels = PathSound.travels;
    await pumpPath(tester, state, walkFrom: 1);

    // Nothing has fired yet: the camera is still finding the stop the signal
    // leaves from, and an impulse that sets off mid-scroll is one nobody sees
    // start.
    expect(find.text('Back to Home').hitTestable(), findsNothing);
    expect(PathSound.travels, travels);

    // The find, the breath, the fire, the conduction, the landing.
    await letTheWalkFinish(tester);

    expect(find.text('Day 2 of 21.'), findsOneWidget);
    expect(find.text('19 days to go.'), findsOneWidget);
    expect(find.text('Back to Home').hitTestable(), findsOneWidget);
    expect(
      PathSound.travels,
      travels + 1,
      reason: 'one impulse, one chime, and nothing else on arrival',
    );
  });

  testWidgets('the chime starts with the movement, not before it', (
    tester,
  ) async {
    // One sound, and it belongs to the green moving: it starts as the signal
    // leaves day one and runs as long as the climb, so it ends on the arrival
    // without a second sound to mark it.
    final state = await path(startedDaysAgo: 1, keptDays: [1], seenStop: 1);
    final travels = PathSound.travels;

    await pumpPath(tester, state, walkFrom: 1);

    // Still finding the stop: nothing has fired.
    await tester.pump(const Duration(milliseconds: 900));
    expect(PathSound.travels, travels, reason: 'not while the page slides');

    // Past the find and the breath, partway up the fibre.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(PathSound.travels, travels + 1, reason: 'the chime has started');
    expect(find.text('Back to Home').hitTestable(), findsNothing);

    await letTheWalkFinish(tester);
    expect(PathSound.travels, travels + 1, reason: 'and it played once');
  });

  testWidgets('an ordinary visit neither walks nor rings', (tester) async {
    // The path is somewhere you can wander into any time. A screen that
    // re-enacts your progress on every visit is a screen you stop visiting.
    final state = await path(startedDaysAgo: 1, keptDays: [1], seenStop: 2);

    final travels = PathSound.travels;
    await pumpPath(tester, state);
    await letTheWalkFinish(tester);

    expect(find.text('Back to Home').hitTestable(), findsNothing);
    expect(find.textContaining('Day 2 of 21.'), findsNothing);
    expect(PathSound.travels, travels);
  });

  testWidgets('the last day says so rather than counting down to it', (
    tester,
  ) async {
    final state = await path(
      startedDaysAgo: 20,
      keptDays: [for (var d = 1; d <= 20; d++) d],
      seenStop: 20,
    );
    expect(state.challengeStop, kChallengeLength);

    await pumpPath(tester, state, walkFrom: 20);
    await letTheWalkFinish(tester);

    expect(find.text('Day 21 of 21.'), findsOneWidget);
    expect(
      find.text('That is the whole path. It is a habit now.'),
      findsOneWidget,
    );
  });

  test('standing on day two sets up a real walk, not a fake one', () async {
    // The review hook behind the demo-data flag. It arranges the state
    // somebody is in on the morning after keeping day one and nothing else —
    // the walk that follows runs on the ordinary trigger.
    final state = await path(
      startedDaysAgo: 0,
      keptDays: [0],
      seenStop: 1,
      habitDaysAgo: 3,
    );
    expect(state.challengeElapsed, 1, reason: 'started today');
    expect(state.challengeAdvanceFrom, isNull, reason: 'nothing to walk yet');

    await state.rehearseChallengeDay();

    expect(state.challengeElapsed, 2);
    expect(state.challengeStop, 2);
    expect(state.challengeAdvanceFrom, 1);
  });

  test('starting the challenge counts day one as already reached', () async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    await storage.markSeeded();
    final state = AppState(storage);
    await state.load();

    await state.startChallenge();

    expect(state.challengeStop, 1);
    expect(state.challengeSeenStop, 1);
    expect(
      state.challengeAdvanceFrom,
      isNull,
      reason: 'arriving where you just chose to stand is not an arrival',
    );
  });

  test('the day after a kept day, the path has a stop to walk to', () async {
    // Started yesterday, kept yesterday. Today is day two.
    final state = await path(startedDaysAgo: 1, keptDays: [1], seenStop: 1);

    expect(state.challengeElapsed, 2);
    expect(state.challengeStop, 2, reason: 'yesterday kept earns today');
    expect(state.challengeAdvanceFrom, 1, reason: 'walk from day one to two');
  });

  test('watching it once is enough for the day', () async {
    final state = await path(startedDaysAgo: 1, keptDays: [1], seenStop: 1);
    expect(state.challengeAdvanceFrom, 1);

    await state.markChallengeStopSeen();

    expect(state.challengeSeenStop, 2);
    expect(
      state.challengeAdvanceFrom,
      isNull,
      reason: 'reopening the app the same day walks nothing',
    );
  });

  test('a missed day starts the challenge again, today', () async {
    // Three days in, and yesterday was not kept. The rules say it goes back
    // to day one — so it does: today is day one, and the path, the count and
    // the arrows all say so. There is nothing to walk and nothing to
    // congratulate anybody for.
    final state = await path(startedDaysAgo: 2, keptDays: [2], seenStop: 1);

    expect(state.perfectStreak, 0);
    expect(state.challengeStartedOn, state.today);
    expect(state.challengeElapsed, 1);
    expect(state.challengeStop, 1);
    expect(state.challengeDay, 0);
    expect(state.challengeAdvanceFrom, isNull);
  });

  test('a missed day in the middle keeps the days kept since', () async {
    // Missed three days ago, kept the two after. The new run began the day
    // after the miss: that is day one, and today is day three of it.
    final state = await path(
      startedDaysAgo: 5,
      keptDays: [5, 4, 2, 1],
      seenStop: 1,
    );
    expect(state.challengeElapsed, 3);
    expect(state.challengeStop, 3);
  });

  test(
    'a past challenge day is locked; today and earlier days are not',
    () async {
      final state = await path(
        startedDaysAgo: 2,
        keptDays: [2, 1],
        seenStop: 1,
        habitDaysAgo: 10,
      );
      final t = state.today;
      expect(state.challengeLocks(t), isFalse, reason: 'today is still open');
      expect(state.challengeLocks(t.subtract(const Duration(days: 1))), isTrue);
      expect(state.challengeLocks(t.subtract(const Duration(days: 2))), isTrue);
      expect(
        state.challengeLocks(t.subtract(const Duration(days: 5))),
        isFalse,
        reason: 'before the challenge began',
      );

      // Changing one anyway, and saying yes: back to day one, today.
      final habit = state.everyHabit.single;
      await state.setValue(habit, t.subtract(const Duration(days: 1)), 0);
      await state.restartChallenge();
      expect(state.challengeStartedOn, t);
      expect(state.challengeStop, 1);
      expect(
        state.challengeLocks(t.subtract(const Duration(days: 1))),
        isFalse,
      );
    },
  );

  test('the walk covers the gap when somebody was away for days', () async {
    // Kept every day of a four-day run but has not opened the app since day
    // one. One walk, from where they last watched to where they are now —
    // rather than three queued animations.
    final state = await path(
      startedDaysAgo: 3,
      keptDays: [1, 2, 3],
      seenStop: 1,
    );

    expect(state.challengeStop, 4);
    expect(state.challengeAdvanceFrom, 1);
  });

  test('a challenge nobody started walks nothing', () async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    await storage.markSeeded();
    final state = AppState(storage);
    await state.load();

    expect(state.challengeLive, isFalse);
    expect(state.challengeStop, 0);
    expect(state.challengeAdvanceFrom, isNull);
  });

  test('giving up clears the walk as well as the challenge', () async {
    final state = await path(startedDaysAgo: 1, keptDays: [1], seenStop: 1);
    expect(state.challengeAdvanceFrom, 1);

    await state.leaveChallenge();

    expect(state.challengeLive, isFalse);
    expect(state.challengeSeenStop, 0);
    expect(state.challengeAdvanceFrom, isNull);

    // And starting again begins at day one, not where the last attempt ended.
    await state.startChallenge();
    expect(state.challengeStop, 1);
    expect(state.challengeAdvanceFrom, isNull);
  });

  test('the trail never runs past the end of the path', () async {
    // Long past the twenty-first day, still keeping it. The path has run out
    // of stops and the number must not walk off the top of it.
    final state = await path(
      startedDaysAgo: 30,
      keptDays: [for (var d = 1; d <= 30; d++) d],
      seenStop: 20,
    );

    expect(state.challengeElapsed, 31);
    expect(state.challengeStop, kChallengeLength);
    expect(state.challengeAdvanceFrom, 20);

    await state.markChallengeStopSeen();
    expect(state.challengeAdvanceFrom, isNull, reason: 'and stays there');
  });

  test('the stop you stand on never goes backwards during a day', () async {
    // The morning of day three with two days kept: standing on stop three
    // before today is finished. Finishing today must not move it again.
    final state = await path(startedDaysAgo: 2, keptDays: [1, 2], seenStop: 2);
    expect(state.challengeStop, 3);

    await state.setValue(state.everyHabit.first, state.today, 1);

    expect(state.challengeStop, 3, reason: 'the stop was already earned');
    expect(state.challengeDay, 3, reason: 'and now the day is kept too');
  });
}
