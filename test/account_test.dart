import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/screens/account_screen.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Account is down to two things: who you are, and the one action in the app
/// that cannot be undone. The counts, the clipboard copy and the export rows
/// moved off it — they were a second copy of what Your Data already does, and
/// the name-and-photo row repeated the pencil in the header directly above it.
void main() {
  Future<void> pump(WidgetTester tester, AppState state) async {
    disableQuoteAutoAdvance();
    disableHeroWalk();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it shows who you are, and nothing it does not own', (
    tester,
  ) async {
    final state = await seededState();
    await pump(tester, state);

    await state.updateProfile(state.profile.copyWith(name: 'Ada'));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text(AppContent.accountDeleteTitle), findsOneWidget);

    // These all live on Your Data now. Two screens offering the same export
    // is two screens to keep in step.
    expect(find.text(AppContent.accountExportTitle), findsNothing);
    expect(find.text(AppContent.accountHabits), findsNothing);
  });

  testWidgets('deleting asks first, and cancelling changes nothing', (
    tester,
  ) async {
    final state = await seededState();
    final before = state.everyHabit.length;
    await pump(tester, state);

    await tester.tap(find.text(AppContent.accountDeleteTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppContent.accountDeleteConfirm), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(state.everyHabit.length, before);
  });

  testWidgets('confirming takes the account and the record with it', (
    tester,
  ) async {
    final state = await seededState();
    expect(state.everyHabit, isNotEmpty);
    await pump(tester, state);

    await tester.tap(find.text(AppContent.accountDeleteTitle));
    await tester.pumpAndSettle();
    // Scoped to the button: the row, the dialog title and the action all read
    // the same, which is right for the user and ambiguous for a finder.
    await tester.tap(
      find.widgetWithText(TextButton, AppContent.accountDeleteTitle),
    );
    await tester.pumpAndSettle();
    await letToastPass(tester);

    expect(state.everyHabit, isEmpty);
    expect(state.checkInCount, 0);
    expect(state.noteCount, 0);
    expect(
      state.profile.name,
      isEmpty,
      reason: 'deleting the account takes the person as well as the record',
    );

    // And it stayed gone.
    expect((await reopen()).everyHabit, isEmpty);
  });

  group('starting over', () {
    testWidgets('clears the record and keeps the person', (tester) async {
      final state = await seededState();
      await state.updateProfile(state.profile.copyWith(name: 'Ada'));
      const name = 'Ada';
      expect(state.everyHabit, isNotEmpty);

      await state.startChallenge();
      await state.startOver();

      expect(state.everyHabit, isEmpty);
      expect(state.checkInCount, 0);
      expect(state.noteCount, 0);
      expect(
        state.challengeLive,
        isFalse,
        reason: 'a clean page is not halfway through a challenge',
      );
      expect(
        state.needsChallengeRules,
        isTrue,
        reason: 'and it starts from agreeing to them again, not from the path',
      );
      expect(
        state.profile.name,
        name,
        reason: 'starting over is not the same as leaving — the name stays',
      );

      expect((await reopen()).everyHabit, isEmpty);
    });
  });
}
