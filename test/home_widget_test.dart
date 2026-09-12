import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/widget_content.dart';
import 'package:rewiremind/models/day_phase.dart';
import 'package:rewiremind/notifications/home_widget_service.dart';

import 'helpers.dart';

/// The widget is the only part of the app that talks to somebody who is not
/// using it, and it is doing that on a home screen where getting the tone wrong
/// is what gets it removed. The ladder from pleased to sad is therefore worth
/// pinning down exactly.
void main() {
  WidgetFace face({
    int streak = 3,
    int scheduled = 4,
    int done = 0,
    int since = 0,
    bool hasHabits = true,
    String phase = 'day',
    int? challengeDay,
    String? name,
  }) => HomeWidgetService.faceFor(
    streak: streak,
    pathLength: 21,
    scheduledToday: scheduled,
    doneToday: done,
    daysSinceSeen: since,
    hasHabits: hasHabits,
    phase: phase,
    challengeDay: challengeDay,
    name: name,
    rng: Random(7),
  );

  test('a fresh install is not accused of having wandered off', () {
    // Nothing logged means the "days since we saw you" count is at its
    // maximum, which used to put a sad face and "Still there?" in front of
    // somebody who installed the app a minute ago.
    final f = face(scheduled: 0, hasHabits: false, since: 31);
    expect(f.mood, WidgetMood.nudge);
    expect(WidgetContent.firstRun.map((l) => l.long), contains(f.line));
  });

  test('a finished day is a happy one', () {
    final f = face(scheduled: 4, done: 4);
    expect(f.mood, WidgetMood.happy);
    expect(WidgetContent.done.map((l) => l.long), contains(f.line));
    expect(f.streak, 'All done ✓');
  });

  test('a started day nudges rather than celebrating', () {
    final f = face(scheduled: 4, done: 2);
    expect(f.mood, WidgetMood.nudge);
    expect(f.streak, '2 habits left');
  });

  test('an untouched day asks', () {
    final f = face(scheduled: 3, done: 0);
    expect(f.mood, WidgetMood.nudge);
    expect(WidgetContent.waiting.map((l) => l.long), contains(f.line));
  });

  test('one quiet day is not sulked over', () {
    expect(
      face(since: 1).mood,
      WidgetMood.nudge,
      reason: 'a single missed day is a normal week',
    );
  });

  test('two quiet days, and it misses you by name', () {
    final f = face(since: 2, name: 'Paras');
    expect(f.mood, WidgetMood.sad);
    expect(WidgetContent.missed('Paras').map((l) => l.long), contains(f.line));

    // Over enough draws the named line has to actually come up, or the name
    // is decorative.
    final seen = <String>{};
    for (var i = 0; i < 60; i++) {
      seen.add(
        HomeWidgetService.faceFor(
          streak: 0,
          pathLength: 21,
          scheduledToday: 2,
          doneToday: 0,
          daysSinceSeen: 4,
          name: 'Paras',
          rng: Random(i),
        ).line,
      );
    }
    expect(seen, contains('I miss you, Paras.'));
    expect(seen, contains('Gone?'));
  });

  test('no name still reads as a sentence', () {
    final lines = WidgetContent.missed(null);
    expect(lines.map((l) => l.long), contains('I miss you.'));
    expect(
      lines.any((l) => l.long.contains('null') || l.short.contains('null')),
      isFalse,
    );
  });

  test('a day with nothing scheduled says so rather than nagging', () {
    expect(face(scheduled: 0, done: 0).streak, 'Nothing today');
  });

  test('the chip counts what is left, on every size', () {
    // The one question a home screen gets glanced at to answer. It used to be
    // the challenge, then a streak — both facts about the past.
    expect(face(scheduled: 4, done: 1).streak, '3 habits left');
    expect(face(scheduled: 4, done: 1).streakShort, '3 habits left');
    expect(face(scheduled: 4, done: 3).streak, '1 habit left');
    expect(face(scheduled: 9, done: 0).streak, '9 habits left');
  });

  test('a finished day stops counting', () {
    // "4 of 4" at somebody who finished at nine in the morning is a widget
    // still asking for something.
    expect(face(scheduled: 4, done: 4).streak, 'All done ✓');
    expect(face(scheduled: 4, done: 4).streakShort, 'All done ✓');
  });

  test('a rest day says so rather than showing a zero', () {
    expect(face(scheduled: 0, done: 0).streak, 'Nothing today');
  });

  test('the chip never goes negative', () {
    // Logging more than the target is allowed, and the arithmetic behind the
    // chip is a subtraction.
    expect(face(scheduled: 2, done: 5).streak, 'All done ✓');
  });

  test('the count outranks the challenge and the streak', () {
    // Both used to win this space. Neither answers "what do I still owe".
    expect(
      face(scheduled: 4, done: 1, challengeDay: 9).streak,
      '3 habits left',
    );
    expect(face(scheduled: 4, done: 1, streak: 30).streak, '3 habits left');
  });

  test('the streak moved to the line under it', () {
    expect(
      face(scheduled: 4, done: 1, challengeDay: 9).sub,
      'Challenge · day 9 of 21',
    );
    expect(
      face(scheduled: 4, done: 1, streak: 30).sub,
      '🔥 30 days, all done',
    );
    expect(
      face(scheduled: 4, done: 1, streak: 1).sub,
      'A streak starts today',
    );
    expect(face(scheduled: 0, streak: 0).sub, 'Nothing due today');
  });

  test('the challenge day under it clamps to the length of the path', () {
    expect(face(challengeDay: 40).sub, 'Challenge · day 21 of 21');
    expect(face(challengeDay: -3).sub, 'Challenge · day 0 of 21');
  });

  test('an untouched day speaks to the hour it is', () {
    // The character is chosen from the clock as well as the mood, so a brain
    // already in bed asking "Warmed up. You?" would be a picture and a line
    // written by two people who never met.
    for (final (phase, pool) in [
      ('earlyMorning', WidgetContent.waitingMorning),
      ('day', WidgetContent.waiting),
      ('night', WidgetContent.waitingNight),
    ]) {
      expect(
        pool.map((l) => l.long),
        contains(face(scheduled: 3, done: 0, phase: phase).line),
        reason: '$phase got a line from the wrong time of day',
      );
    }
  });

  test('a phase nobody recognises still gets a sentence', () {
    expect(
      WidgetContent.waiting.map((l) => l.long),
      contains(face(scheduled: 3, done: 0, phase: 'teatime').line),
    );
  });

  test('the hour does not overrule a finished day or a fortnight away', () {
    // These two are worth saying whatever the clock says, and they are the two
    // the mood keeps for itself.
    expect(face(scheduled: 4, done: 4, phase: 'night').mood, WidgetMood.happy);
    expect(face(since: 5, phase: 'earlyMorning').mood, WidgetMood.sad);
  });

  test('an update picks a line other than the one already showing', () {
    final rng = Random(1);
    for (var i = 0; i < 40; i++) {
      expect(
        WidgetContent.pick(WidgetContent.waiting, 'Got a minute?', rng).long,
        isNot('Got a minute?'),
      );
    }
  });

  test('nothing it can say is long enough to need cutting off', () {
    // The widget layouts have no `ellipsize`, so a line that does not fit is
    // chopped mid-word rather than politely trimmed. The guard is therefore
    // the copy itself: the strip and the square take the short form, and the
    // short form has to stay short.
    final pools = [
      WidgetContent.firstRun,
      WidgetContent.done,
      WidgetContent.partway,
      WidgetContent.waitingMorning,
      WidgetContent.waiting,
      WidgetContent.waitingNight,
      WidgetContent.missed('Bartholomew'),
    ];

    for (final pool in pools) {
      for (final line in pool) {
        expect(
          line.short.length,
          lessThanOrEqualTo(14),
          reason: '"${line.short}" is too long for one row beside a mascot',
        );
        expect(
          line.long.length,
          lessThanOrEqualTo(26),
          reason: '"${line.long}" will not fit two lines on the wide size',
        );
      }
    }
  });

  test('the count has a form that fits a shared row', () {
    // The chip shares the strip with a sentence and a mascot, so every form it
    // can take has to stay chip-sized — including somebody tracking a dozen
    // habits, which is the worst moment for the row to fall apart.
    for (final chip in [
      WidgetContent.chip(doneToday: 0, scheduledToday: 12),
      WidgetContent.chip(doneToday: 11, scheduledToday: 12),
      WidgetContent.chip(doneToday: 4, scheduledToday: 4),
      WidgetContent.chip(doneToday: 0, scheduledToday: 0),
    ]) {
      expect(chip.long.length, lessThanOrEqualTo(14), reason: chip.long);
      expect(chip.short.length, lessThanOrEqualTo(14), reason: chip.short);
    }

    // And the line under it, which has a column rather than a pill but still
    // only one row of it.
    //
    // Twenty-four, not thirty: at thirty this test passed while a real home
    // screen was showing "Finish today to start a", because a 12sp line in
    // that column runs out at about two dozen characters. Every case it can
    // produce is checked, including the one that was wrong.
    for (final line in [
      WidgetContent.sub(challengeDay: 21, pathLength: 21, streak: 21, total: 4),
      WidgetContent.sub(challengeDay: 7, pathLength: 21, streak: 7, total: 4),
      WidgetContent.sub(pathLength: 21, streak: 365, total: 12),
      WidgetContent.sub(pathLength: 21, streak: 12, total: 12),
      WidgetContent.sub(pathLength: 21, streak: 0, total: 0),
      WidgetContent.sub(pathLength: 21, streak: 0, total: 4),
      WidgetContent.sub(pathLength: 21, streak: 1, total: 4),
    ]) {
      expect(line.length, lessThanOrEqualTo(24), reason: line);
    }
  });

  test('the widget is given every line, not just one', () {
    // The widget turns its own copy over by the hour out of this pool, which
    // is what stops a home screen the app has not been opened on since
    // breakfast from still saying "Morning" at six in the evening.
    final f = face(scheduled: 3, done: 0, phase: 'night');
    expect(f.pool, WidgetContent.waitingNight);
    expect(f.lines.split('\n'), hasLength(WidgetContent.waitingNight.length));
    expect(f.lines.split('\n'), contains(f.line));
  });

  test('the pool is never empty, in any state the app can reach', () {
    // Kotlin picks `pool[hour % pool.size]`, so an empty pool is a blank
    // widget on whichever day the app happens to reach that state.
    final states = [
      face(scheduled: 0, hasHabits: false, since: 31),
      face(scheduled: 4, done: 4),
      face(scheduled: 4, done: 2),
      face(scheduled: 3, done: 0, phase: 'earlyMorning'),
      face(scheduled: 3, done: 0, phase: 'day'),
      face(scheduled: 3, done: 0, phase: 'night'),
      face(since: 4, name: 'Paras'),
    ];
    for (final f in states) {
      expect(f.pool, isNotEmpty);
      expect(f.lines, isNot(contains('null')));
      expect(f.linesShort, isNot(contains('null')));
    }
  });

  test('no line has a newline in it to break the pool apart', () {
    // The pool crosses to Kotlin as one newline-separated string, so a line
    // with a newline in it would silently become two.
    for (final pool in [
      WidgetContent.firstRun,
      WidgetContent.done,
      WidgetContent.partway,
      WidgetContent.waitingMorning,
      WidgetContent.waiting,
      WidgetContent.waitingNight,
      WidgetContent.missed('Ada'),
    ]) {
      for (final line in pool) {
        expect(line.long, isNot(contains('\n')));
        expect(line.short, isNot(contains('\n')));
      }
    }
  });

  test('every hour of the day has a character to draw', () {
    // Kotlin indexes HOURS by the clock hour with no bounds check, because a
    // table with a hole in it is a widget that fails at, say, 3am and nowhere
    // else. Twenty-four entries, counted from the source.
    final kotlin =
        Directory('android/app/src/main/kotlin/com/parasjain/rewiremind')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.kt'))
            .map((f) => f.readAsStringSync())
            .join('\n');

    final table = RegExp(
      r'val HOURS = arrayOf\((.*?)\n        \)',
      dotAll: true,
    ).firstMatch(kotlin);
    expect(table, isNotNull, reason: 'the hour table has been renamed');

    final entries = table!
        .group(1)!
        .replaceAll(RegExp(r'//[^\n]*'), '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    expect(entries, hasLength(24));
  });

  test('every size names a receiver the manifest actually declares', () {
    // The only link between Dart and Kotlin here is a class name in a string.
    // Rename the Kotlin class and nothing fails to compile — the widget just
    // silently stops updating, which is exactly the bug worth a test.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    for (final size in WidgetKind.values) {
      expect(
        manifest,
        contains('android:name=".${size.provider}"'),
        reason: '${size.name} points at a receiver that is not declared',
      );
    }

    final kotlin =
        Directory('android/app/src/main/kotlin/com/parasjain/rewiremind')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.kt'))
            .map((f) => f.readAsStringSync())
            .join('\n');

    for (final size in WidgetKind.values) {
      expect(
        kotlin,
        contains('class ${size.provider}'),
        reason: '${size.name} points at a class that does not exist',
      );
    }
  });

  test('every widget layout is made of views RemoteViews will inflate', () {
    // The one that shipped. A plain <View>, used as a spacer to centre the
    // mascot, is not annotated @RemoteView, so the launcher refuses the entire
    // widget and draws "an error has occurred" where it was. Nothing catches
    // this earlier: aapt compiles the layout without complaint and the failure
    // is in another process at runtime.
    //
    // Not the full list — just the ones this app has any reason to reach for,
    // plus the two it is easiest to reach for by accident.
    const allowed = {
      'FrameLayout',
      'LinearLayout',
      'RelativeLayout',
      'GridLayout',
      'TextView',
      'ImageView',
      'Button',
      'ImageButton',
      'ProgressBar',
      'ViewFlipper',
      'ViewStub',
      'AnalogClock',
      'Chronometer',
      'ListView',
      'GridView',
      'StackView',
      'AdapterViewFlipper',
      'CheckBox',
      'RadioGroup',
      'RadioButton',
      'Switch',
      'Space',
    };

    final dir = Directory('android/app/src/main/res/layout');
    final layouts = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.xml'),
    );
    expect(layouts, isNotEmpty, reason: 'no layouts found to check');

    for (final file in layouts) {
      // Comments first, or this catches the <View> named in the comment
      // above explaining why there is no longer a <View>.
      final xml = file.readAsStringSync().replaceAll(
        RegExp(r'<!--.*?-->', dotAll: true),
        '',
      );

      for (final tag in RegExp(
        r'<([A-Za-z][\w.]*)',
      ).allMatches(xml).map((m) => m.group(1)!)) {
        expect(
          allowed,
          contains(tag),
          reason:
              '${file.uri.pathSegments.last} uses <$tag>, which a launcher '
              'cannot inflate in a widget',
        );
      }
    }
  });

  testWidgets('changing the theme repaints the widget too', (tester) async {
    // The widget paints the same sky the app does. Pinning a time of day used
    // to repaint the app and leave the home screen showing the one before it,
    // which is two answers to what time it is on the same screen.
    final state = await emptyState();

    await state.setFixedPhase(DayPhase.night);
    expect(state.homeWidget.lastPhase, 'night');

    await state.setFixedPhase(DayPhase.earlyMorning);
    expect(state.homeWidget.lastPhase, 'earlyMorning');
  });

  testWidgets('the app can say how long it has been', (tester) async {
    final state = await emptyState();
    expect(
      state.daysSinceSeen,
      greaterThan(1),
      reason: 'a fresh install has never been seen',
    );
  });
}
