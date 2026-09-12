import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/screens/roadmap_screen.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// The 21-day path.
///
/// The screen is one big CustomPaint, so what is worth asserting is the
/// arithmetic around it: the count it reports, the fact that it opens from
/// Home, and that a fresh install does not crash on a path with nothing on it.
void main() {
  Future<void> pumpPath(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: RoadmapScreen()),
      ),
    );
    // The intro draws the trail in; the ambient loop never settles, so pump
    // frames rather than waiting for stillness.
    await tester.pump(const Duration(milliseconds: 1800));
  }

  test('there is a medal for every week, and a week for every medal', () {
    expect(kMilestones.length, kWeeks);
    for (var w = 1; w <= kWeeks; w++) {
      expect(
        kMilestones.contains(w * kDaysPerWeek),
        isTrue,
        reason: 'week $w has to end on a milestone',
      );
    }
    // Indexed by `day ~/ kDaysPerWeek - 1`, so a short list is a range error
    // on the day somebody finishes the last week.
    for (final palette in [kMedalFace, kMedalEdge, kMedalRibbon]) {
      expect(palette.length, kWeeks);
    }
  });

  testWidgets('nothing counts until the challenge has been started', (
    tester,
  ) async {
    final state = await seededState();
    expect(
      state.challengeLive,
      isFalse,
      reason: 'a fresh install has not joined anything',
    );

    await pumpPath(tester, state);

    // A run of perfect days behind it, and none of them count: they happened
    // before there was a challenge to count them.
    await keepDay(state, state.today.subtract(const Duration(days: 1)));
    expect(state.perfectStreak, greaterThan(0));
    expect(find.text('0'), findsOneWidget);
    expect(find.text(AppContent.pathOf(kPathLength)), findsOneWidget);
  });

  testWidgets('once started it counts from that day, and no earlier', (
    tester,
  ) async {
    final state = await seededState();
    await keepDay(state, state.today.subtract(const Duration(days: 1)));
    await state.startChallenge();

    // Day one is the day it began, however long the run behind it is.
    expect(state.challengeDay, 1);

    await pumpPath(tester, state);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('the run still has to be unbroken', (tester) async {
    final state = await seededState();
    await state.startChallenge();

    // Break a day that is over. Today is allowed to be unfinished — the run is
    // still alive until midnight — so yesterday is where a miss actually
    // counts, and that is the rule the challenge is built on.
    final yesterday = state.today.subtract(const Duration(days: 1));
    for (final habit in state.scheduledOn(yesterday)) {
      await state.setValue(habit, yesterday, 0);
    }

    expect(state.perfectStreak, lessThan(2));
    expect(
      state.challengeDay,
      0,
      reason: 'a broken day puts the path back to the beginning',
    );
  });

  testWidgets('an empty install opens the path without blowing up', (
    tester,
  ) async {
    final state = await emptyState();
    await pumpPath(tester, state);

    expect(find.text('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the challenge card on Profile opens the path', (tester) async {
    final state = await pumpSeededApp(tester);
    await keepDay(state, state.today.subtract(const Duration(days: 1)));
    final done = state.challengeDay.clamp(0, kPathLength);

    // Nothing on Home any more: tapping the character is on its way to being
    // a conversation with it, and the challenge lives on Profile.
    expect(find.text(AppContent.pathBadge(done, kPathLength)), findsNothing);

    await tester.tap(find.text(AppContent.navProfile));
    await tester.pumpAndSettle();

    // Its own card above the settings list, not a row inside it.
    await tester.tap(find.text(AppContent.challengeCardTitle));
    await tester.pumpAndSettle();

    // The rules come first, once. Nobody should learn that a missed day
    // resets the run by having it happen to them.
    expect(find.text(AppContent.rulesHeadline), findsOneWidget);

    // And they have to be agreed to. The button does nothing until the box is
    // ticked — being shown the rules is not the same as having read them.
    await tester.tap(find.text(AppContent.rulesBegin));
    await tester.pumpAndSettle();
    expect(
      find.text(AppContent.rulesHeadline),
      findsOneWidget,
      reason: 'still on the rules: nothing was agreed to',
    );
    expect(state.challengeLive, isFalse);

    await tester.tap(find.text(AppContent.rulesAgree));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppContent.rulesBegin));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));

    expect(find.text(AppContent.pathTagline), findsOneWidget);
    expect(
      state.challengeLive,
      isTrue,
      reason: 'agreeing and pressing begin is what starts it',
    );
    expect(state.challengeDay, 1);
  });
}
