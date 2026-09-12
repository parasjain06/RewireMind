import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/notifications/path_sound.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/widgets/day_complete_overlay.dart';
import 'package:rewiremind/widgets/habit_row.dart';

import 'helpers.dart';

/// The reward for finishing a day only means something if it is rare. These
/// guard the two ways that gets lost: firing on a partial day, and firing
/// again every time the last habit is toggled.
void main() {
  /// The celebration lives in the app's overlay now, so its presence is the
  /// signal rather than a flag on a widget inside the page.
  bool celebrating(WidgetTester tester) =>
      find.byType(DayCompleteOverlay).evaluate().isNotEmpty;

  /// Lets the overlay run its course and remove itself, so no timer is left
  /// pending when the test ends.
  Future<void> letItPass(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Two frames: one for the state change, one for the post-frame callback
  /// that notices the day closed. `pumpAndSettle` is wrong here — it runs the
  /// clock past the burst *and* its reset, so the flag is already back to
  /// false by the time it returns.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> tickAll(WidgetTester tester, AppState state) async {
    for (final habit in state.scheduledOn(state.today)) {
      if (!state.isComplete(habit, state.today)) {
        await state.setValue(habit, state.today, habit.target);
      }
    }
    await settle(tester);
  }

  testWidgets('a partial day does not celebrate', (tester) async {
    final state = await pumpSeededApp(tester);
    final habits = state.scheduledOn(state.today);
    expect(habits.length, greaterThan(1));

    final closes = PathSound.closes;
    await state.setValue(habits.first, state.today, habits.first.target);
    await settle(tester);

    expect(
      celebrating(tester),
      isFalse,
      reason: 'only the last habit of the day earns the bigger beat',
    );
    expect(PathSound.closes, closes, reason: 'and only it gets the sound');
  });

  testWidgets('finishing the day fires it exactly once', (tester) async {
    final state = await pumpSeededApp(tester);
    final closes = PathSound.closes;
    await tickAll(tester, state);

    expect(celebrating(tester), isTrue);
    expect(PathSound.closes, closes + 1, reason: 'the check plays with it');

    // It clears itself: a celebration you have to dismiss is a chore.
    await letItPass(tester);
    expect(celebrating(tester), isFalse);
  });

  testWidgets('finishing the day again plays it again', (tester) async {
    final state = await pumpSeededApp(tester);
    await tickAll(tester, state);
    expect(celebrating(tester), isTrue, reason: 'the first close fires');
    await letItPass(tester);
    expect(celebrating(tester), isFalse);

    // Undo the last one and put it back: the day becomes whole again, so the
    // moment plays again. Being able to re-watch it is worth more than the
    // purity of firing once.
    final closes = PathSound.closes;
    final last = state.scheduledOn(state.today).last;
    await state.setValue(last, state.today, 0);
    await settle(tester);
    expect(celebrating(tester), isFalse, reason: 'an unfinished day is quiet');

    await state.setValue(last, state.today, last.target);
    await settle(tester);
    expect(celebrating(tester), isTrue);
    expect(
      PathSound.closes,
      closes,
      reason: 'the sound is once a day; closing it again is shown, not heard',
    );
    await letItPass(tester);
  });

  testWidgets('a day finished earlier is not celebrated again on launch', (
    tester,
  ) async {
    // The bug this fixes: what held "we have already done this one" was a
    // field on the Home screen's State, and a cold launch builds a new State.
    // So a day finished last night was finished-and-unannounced again this
    // morning, and the whole screen was taken over by a party for something
    // that had already happened.
    final state = await pumpSeededApp(tester);
    await tickAll(tester, state);
    expect(celebrating(tester), isTrue, reason: 'the first close fires');
    await letItPass(tester);

    // The same day, the same data, a brand new widget tree.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final closes = PathSound.closes;
    await pumpAppWith(tester, state);
    await settle(tester);

    expect(PathSound.closes, closes, reason: 'a quiet morning, not a replay');
    expect(
      celebrating(tester),
      isFalse,
      reason: 'the day was closed once, whatever happens to the widget tree',
    );
  });

  testWidgets('the day-closed note appears and leaves with the day', (
    tester,
  ) async {
    final state = await pumpSeededApp(tester);
    expect(find.text(AppContent.homeDayClosed), findsNothing);

    await tickAll(tester, state);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // No manual scrolling: closing the day brings the end of the list into
    // view by itself, because a note below the fold is a note nobody sees.
    expect(
      find.text(AppContent.homeDayClosed),
      findsOneWidget,
      reason: 'the burst is the moment; the note is the receipt',
    );

    final last = state.scheduledOn(state.today).last;
    await state.setValue(last, state.today, 0);
    await tester.pumpAndSettle();
    expect(find.text(AppContent.homeDayClosed), findsNothing);
  });

  testWidgets('closing out a past day is not a moment', (tester) async {
    final state = await pumpSeededApp(tester);
    final target = startOfWeek(state.today);
    if (!target.isBefore(state.today)) return; // today is Monday

    await tester.tap(find.text('${target.day}').first);
    await tester.pumpAndSettle();

    for (final habit in state.scheduledOn(target)) {
      if (!state.isComplete(habit, target)) {
        await state.setValue(habit, target, habit.target);
      }
    }
    await settle(tester);

    expect(
      celebrating(tester),
      isFalse,
      reason: 'backfilling last Tuesday is bookkeeping, not an achievement',
    );
  });

  testWidgets('closing the day scrolls the note into view', (tester) async {
    final state = await pumpSeededApp(tester);
    final list = find.byType(Scrollable).last;

    final before = tester.widget<Scrollable>(list).controller!.offset;
    expect(before, 0, reason: 'the list starts at the top');

    await tickAll(tester, state);
    await letItPass(tester);

    final after = tester.widget<Scrollable>(list).controller!.offset;
    expect(
      after,
      greaterThan(before),
      reason: 'the end of the list has to come to the user',
    );
    expect(find.text(AppContent.homeDayClosed), findsOneWidget);
  });

  testWidgets('an already-completed habit shows its check mark', (
    tester,
  ) async {
    // Nothing animates on a habit that was already done when the row was
    // built, so a check driven purely by the animation would render at zero
    // opacity — a blank green disc.
    final state = await seededState();
    final habit = state.habits.first;
    await state.setValue(habit, state.today, habit.target);

    await pumpAppWith(tester, state);

    final mark = find.descendant(
      of: find.ancestor(
        of: find.text(habit.name),
        matching: find.byType(HabitCheckRow),
      ),
      matching: find.byIcon(Icons.check),
    );
    expect(mark, findsOneWidget);

    final opacity = tester.widget<Opacity>(
      find.ancestor(of: mark, matching: find.byType(Opacity)).first,
    );
    expect(
      opacity.opacity,
      1.0,
      reason: 'the tick has to be visible, not merely present',
    );
  });

  testWidgets('the tick circle survives being tapped', (tester) async {
    final state = await pumpSeededApp(tester);
    final habit = state.scheduledOn(state.today).first;

    final circle = find.descendant(
      of: find.ancestor(
        of: find.text(habit.name),
        matching: find.byType(HabitCheckRow),
      ),
      matching: find.byType(CheckButton),
    );
    expect(circle, findsOneWidget);

    await tester.tap(circle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(state.isComplete(habit, state.today), isTrue);
    expect(tester.takeException(), isNull);

    // And undoing it, which must not throw on the reversed animation.
    await tester.tap(circle);
    await tester.pumpAndSettle();
    expect(state.isComplete(habit, state.today), isFalse);
    expect(tester.takeException(), isNull);
  });
}
