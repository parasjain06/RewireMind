import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/app.dart';
import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/screens/home_shell.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// The walkthrough on a first launch.
///
/// Worth pinning down in both directions: it has to appear once, and it must
/// never appear twice. A tour that comes back is worse than no tour.
void main() {
  Future<void> pump(WidgetTester tester, AppState state) async {
    disableQuoteAutoAdvance();
    disableHeroWalk();
    showTutorialOnFirstRun = true;
    addTearDown(() => showTutorialOnFirstRun = false);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const RewireMindApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a first launch explains itself before showing an empty list', (
    tester,
  ) async {
    final state = await emptyState();
    expect(state.needsTutorial, isTrue);

    await pump(tester, state);

    expect(
      find.text(AppContent.howSlides.first.title),
      findsOneWidget,
      reason: 'an empty screen with a plus sign on it explains nothing',
    );

    // Skipping still counts as having been offered it.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(state.needsTutorial, isFalse);

    // Then, by itself, a look round Home: the real screen, one part at a
    // time.
    expect(find.text(AppContent.coachHeroTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coachAdvance')));
    await tester.pumpAndSettle();
    expect(find.text(AppContent.coachStatsTitle), findsOneWidget);
    expect(find.text(AppContent.coachHeroTitle), findsNothing);

    // And Skip ends the whole of it, from any step.
    await tester.tap(find.text(AppContent.coachSkip));
    await tester.pumpAndSettle();
    expect(find.text(AppContent.coachStatsTitle), findsNothing);
    expect(find.text(AppContent.coachAddTitle), findsNothing);

    // Last, the widget.
    expect(find.text(AppContent.widgetTitle), findsOneWidget);
    await tester.tap(find.text(AppContent.widgetSkip));
    await tester.pumpAndSettle();
  });

  testWidgets('the Home tour can be walked to the end', (tester) async {
    final state = await emptyState();
    await pump(tester, state);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // A tap through every step that has something on screen to point at; the
    // last one has no Skip left to press.
    for (
      var i = 0;
      i < 8 && find.text(AppContent.coachTabsTitle).evaluate().isEmpty;
      i++
    ) {
      await tester.tap(find.byKey(const ValueKey('coachAdvance')));
      await tester.pumpAndSettle();
    }
    expect(find.text(AppContent.coachTabsTitle), findsOneWidget);
    expect(find.text(AppContent.coachSkip), findsNothing);

    // The last step says tapping finishes it, and it does.
    expect(find.text(AppContent.coachTapDone), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coachAdvance')));
    await tester.pumpAndSettle();
    expect(find.text(AppContent.coachTabsTitle), findsNothing);
  });

  testWidgets('it does not come back on the next launch', (tester) async {
    final first = await emptyState();
    await pump(tester, first);
    expect(find.text(AppContent.howSlides.first.title), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Same storage, reopened — which is what a second launch is.
    final again = await reopen();
    expect(again.needsTutorial, isFalse);
    await pump(tester, again);
    expect(find.text(AppContent.howSlides.first.title), findsNothing);
  });

  testWidgets('deleting everything earns an introduction again', (
    tester,
  ) async {
    final state = await emptyState();
    await state.markTutorialSeen();
    expect(state.needsTutorial, isFalse);

    await state.resetAll();
    expect(
      state.needsTutorial,
      isTrue,
      reason: 'a wiped install is a new one, and should be told how it works',
    );
  });

  testWidgets('How it works ends with a way back into the walkthrough', (
    tester,
  ) async {
    final state = await seededState();
    await pumpAppWith(tester, state);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();

    for (var i = 1; i < AppContent.howSlides.length; i++) {
      await tester.tap(find.text(AppContent.howNext));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(AppContent.howTour));
    await tester.pumpAndSettle();

    // Back on Home, with the walkthrough running.
    expect(find.text(AppContent.coachHeroTitle), findsOneWidget);
    await tester.tap(find.text(AppContent.coachSkip));
    await tester.pumpAndSettle();
    expect(find.text(AppContent.coachHeroTitle), findsNothing);
  });

  testWidgets('Fresh install puts everything back as it was installed', (
    tester,
  ) async {
    final state = await seededState();
    await state.markTutorialSeen();
    await state.startChallenge();
    await state.setNotifyPrefs(state.notifyPrefs.copyWith(enabled: true));
    await pumpAppWith(tester, state);

    await state.freshInstall();
    await tester.pumpAndSettle();

    expect(state.profile.name, isEmpty, reason: 'back to the sign-in screen');
    expect(state.everyHabit, isEmpty);
    expect(state.challengeLive, isFalse);
    expect(state.notifyPrefs.enabled, isFalse);
    expect(state.needsTutorial, isTrue, reason: 'the slides and tour again');
    expect(find.byType(HomeShell), findsNothing);
  });
}
