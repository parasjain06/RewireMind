import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/widgets/habit_row.dart';

import 'helpers.dart';

/// Past days of a running challenge are locked: a change asks first, and
/// going ahead restarts the challenge from day one.
void main() {
  testWidgets('changing yesterday asks, and restarts only on a yes', (
    tester,
  ) async {
    final state = await seededState();
    await state.rehearseChallengeDay(days: 3);
    final yesterday = state.today.subtract(const Duration(days: 1));
    final started = state.challengeStartedOn;
    expect(state.challengeLocks(yesterday), isTrue);

    await pumpAppWith(tester, state);
    state.viewDay(yesterday);
    await tester.pumpAndSettle();

    final habit = state.scheduledOn(yesterday).first;
    final before = state.valueOf(habit.id, yesterday);

    // "Keep it": nothing changes.
    await tester.tap(find.byType(CheckButton).first);
    await tester.pumpAndSettle();
    expect(find.text(AppContent.challengeLockTitle), findsOneWidget);
    await tester.tap(find.text(AppContent.challengeLockKeep));
    await tester.pumpAndSettle();
    expect(state.valueOf(habit.id, yesterday), before);
    expect(state.challengeStartedOn, started);

    // "Change & restart": the change is made and today is day one.
    await tester.tap(find.byType(CheckButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppContent.challengeLockGo));
    await tester.pumpAndSettle();
    expect(state.valueOf(habit.id, yesterday), isNot(before));
    expect(state.challengeStartedOn, state.today);
    expect(state.challengeStop, 1);
    expect(find.text(AppContent.challengeRestarted), findsOneWidget);
    await letToastPass(tester);
  });

  testWidgets('today changes freely, challenge or not', (tester) async {
    final state = await seededState();
    await state.rehearseChallengeDay(days: 3);
    final started = state.challengeStartedOn;
    await pumpAppWith(tester, state);

    await tester.tap(find.byType(CheckButton).first);
    await tester.pumpAndSettle();
    expect(find.text(AppContent.challengeLockTitle), findsNothing);
    expect(state.challengeStartedOn, started);
  });
}
