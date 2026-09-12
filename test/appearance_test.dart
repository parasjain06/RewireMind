import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/models/day_phase.dart';
import 'package:rewiremind/screens/appearance_screen.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Pinning the time of day is a setting rather than a preview: it has to
/// outlast the app being closed, and it has to move the whole palette and not
/// just the header artwork.
void main() {
  Future<void> pump(WidgetTester tester, AppState state) async {
    disableQuoteAutoAdvance();
    disableHeroWalk();
    // A phone rather than the 800x600 default: this page is a scrolling list
    // and the default surface is short enough to push the last row under the
    // fold, where a tap cannot reach it.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: AppearanceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('off by default, and the clock is what paints the page', (
    tester,
  ) async {
    final state = await emptyState();
    await pump(tester, state);

    expect(state.fixedPhase, isNull);
    expect(state.followsClock, isTrue);
    // The choices only appear once the switch is on.
    expect(find.text(DayPhase.day.label), findsNothing);
  });

  testWidgets('turning it on offers every time of day', (tester) async {
    final state = await emptyState();
    await pump(tester, state);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    for (final phase in DayPhase.values) {
      expect(find.text(phase.label), findsOneWidget, reason: phase.name);
      expect(find.text(AppContent.phaseHours(phase)), findsOneWidget);
    }
    // It starts from whatever was already on screen, so nothing jumps.
    expect(state.fixedPhase, isNotNull);
  });

  testWidgets('choosing one repaints the whole page, not just the header', (
    tester,
  ) async {
    final state = await emptyState();
    await pump(tester, state);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.text(DayPhase.night.label));
    await tester.pumpAndSettle();

    expect(state.activePhase, DayPhase.night);
    expect(state.theme.brightness, Brightness.dark);
    expect(state.followsClock, isFalse);
  });

  testWidgets('the choice survives a restart, and can be handed back', (
    tester,
  ) async {
    final state = await emptyState();
    await state.setFixedPhase(DayPhase.night);

    final reopened = await reopen();
    expect(
      reopened.fixedPhase,
      DayPhase.night,
      reason: 'a setting, not a preview — it has to persist',
    );

    await reopened.setFixedPhase(null);
    expect((await reopen()).fixedPhase, isNull);
  });
}
