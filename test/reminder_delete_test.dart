import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/models/reminder.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Deleting a reminder has to remove it from the screen, not just from
/// storage — a row that survives its own deletion reads as a failed tap and
/// invites a second one.
void main() {
  Future<AppState> stateWith(List<Reminder> reminders) async {
    final state = await seededState();
    await state.setNotifyPrefs(
      state.notifyPrefs.copyWith(
        enabled: true,
        catchUpEnabled: false,
        challengeEnabled: false,
        generalEnabled: true,
        reminders: reminders,
      ),
    );
    return state;
  }

  Reminder reminder({
    String id = 'r1',
    String text = 'Morning walk',
    String? habitId,
    TimeOfDayValue time = const TimeOfDayValue(8, 30),
  }) => Reminder(id: id, text: text, habitId: habitId, time: time);

  /// Taps a delete icon and lets the confirmation run its course, so no
  /// dismiss timer is left pending when the test ends.
  Future<void> deleteFirst(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
  }

  Future<void> letToastPass(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Tall enough that the reminder rows are built. The settings screen reads
  /// top to bottom and a lazy list does not build what is below the fold.
  void tallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openReminders(WidgetTester tester) async {
    tallWindow(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
  }

  testWidgets('the trash icon removes the row from the reminders screen', (
    tester,
  ) async {
    final state = await stateWith([
      reminder(id: 'a', text: 'Morning walk'),
      reminder(
        id: 'b',
        text: 'Evening review',
        time: const TimeOfDayValue(20, 0),
      ),
    ]);
    await pumpAppWith(tester, state);
    await openReminders(tester);

    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Evening review'), findsOneWidget);

    await deleteFirst(tester);

    expect(state.notifyPrefs.reminders.map((r) => r.id), [
      'b',
    ], reason: 'the right one was removed from storage');
    expect(
      find.text('Morning walk'),
      findsNothing,
      reason: 'a deleted reminder must leave the screen',
    );
    expect(find.text('Evening review'), findsOneWidget);
    await letToastPass(tester);
  });

  testWidgets('deleting the last reminder leaves the empty state', (
    tester,
  ) async {
    final state = await stateWith([reminder()]);
    await pumpAppWith(tester, state);
    await openReminders(tester);

    await deleteFirst(tester);

    expect(find.text('Morning walk'), findsNothing);
    expect(state.notifyPrefs.reminders, isEmpty);
    await letToastPass(tester);
  });

  testWidgets('the trash icon removes the row from the habit screen', (
    tester,
  ) async {
    final state = await seededState();
    final habit = state.habits.first;
    await state.setNotifyPrefs(
      state.notifyPrefs.copyWith(
        enabled: true,
        catchUpEnabled: false,
        challengeEnabled: false,
        generalEnabled: true,
        reminders: [reminder(id: 'h1', text: 'Drink up', habitId: habit.id)],
      ),
    );

    await pumpAppWith(tester, state);
    await tester.tap(find.text(habit.name));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Drink up'), 150);
    expect(find.text('Drink up'), findsOneWidget);

    await deleteFirst(tester);

    expect(state.notifyPrefs.reminders, isEmpty);
    expect(
      find.text('Drink up'),
      findsNothing,
      reason: 'a deleted reminder must leave the habit screen too',
    );
    await letToastPass(tester);
  });

  testWidgets('Undo puts it back on the screen', (tester) async {
    final state = await stateWith([reminder()]);
    await pumpAppWith(tester, state);
    await openReminders(tester);

    await deleteFirst(tester);
    expect(find.text('Morning walk'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(state.notifyPrefs.reminders, hasLength(1));
    expect(
      find.text('Morning walk'),
      findsOneWidget,
      reason: 'undo has to restore the row, not only the record',
    );
  });

  testWidgets('the confirmation clears itself instead of sitting there', (
    tester,
  ) async {
    final state = await stateWith([reminder()]);
    await pumpAppWith(tester, state);
    await openReminders(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect(find.text('Reminder deleted'), findsOneWidget);

    await letToastPass(tester);

    expect(
      find.text('Reminder deleted'),
      findsNothing,
      reason: 'a toast that never leaves reads as a stuck screen',
    );
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('deleting several does not stack a queue of confirmations', (
    tester,
  ) async {
    final state = await stateWith([
      reminder(id: 'a', text: 'One'),
      reminder(id: 'b', text: 'Two', time: const TimeOfDayValue(9, 0)),
      reminder(id: 'c', text: 'Three', time: const TimeOfDayValue(10, 0)),
    ]);
    await pumpAppWith(tester, state);
    await openReminders(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
    }
    await letToastPass(tester);

    expect(state.notifyPrefs.reminders, isEmpty);
    expect(
      find.text('Reminder deleted'),
      findsNothing,
      reason: 'queued toasts would keep the screen busy for 12 seconds',
    );
  });
}
