import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/app.dart';
import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// There is no server behind this app, so "signing in" is one question: what
/// should it call you. But it is a real gate — until it is answered there is
/// no profile, and the app has to say so rather than greeting a stranger by
/// somebody else's name, which is what it used to do.
void main() {
  Future<AppState> namelessState() async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});
    final storage = await RewireMindStorage.open();
    await storage.markSeeded();
    final state = AppState(storage);
    await state.load();
    return state;
  }

  Future<void> pump(WidgetTester tester, AppState state) async {
    disableQuoteAutoAdvance();
    disableHeroWalk();
    disableFirstRunTutorial();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const RewireMindApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a nameless profile lands on sign-in, not on Home', (
    tester,
  ) async {
    final state = await namelessState();
    expect(state.profile.name, isEmpty);

    await pump(tester, state);

    expect(find.text(AppContent.signInTitle), findsOneWidget);
    expect(find.text(AppContent.navHome), findsNothing);
  });

  testWidgets('the button waits for a name', (tester) async {
    final state = await namelessState();
    await pump(tester, state);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppContent.signInGo),
    );
    expect(
      button.onPressed,
      isNull,
      reason: 'an empty name is not an answer to the only question here',
    );
  });

  testWidgets('a name gets you in, and it sticks', (tester) async {
    final state = await namelessState();
    await pump(tester, state);

    await tester.enterText(find.byType(TextField), '  Ada  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppContent.signInGo));
    await tester.pumpAndSettle();

    expect(find.text(AppContent.navHome), findsOneWidget);
    expect(
      state.profile.name,
      'Ada',
      reason: 'trimmed: nobody meant the spaces',
    );

    // And it survives a restart, or the gate would close behind them.
    expect((await reopen()).profile.name, 'Ada');
  });
}
