import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';

import 'helpers.dart';

/// Profile has a single edit entry point — a pencil beside the name — and it
/// covers the quote as well. There used to be two separate "Edit" controls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
  }

  Finder editButton() => find.byIcon(Icons.edit_outlined);

  testWidgets('only one edit affordance is offered', (tester) async {
    await pumpSeededApp(tester);
    await openProfile(tester);

    expect(editButton(), findsOneWidget);
    // Neither the old text button nor the quote bar's own control remain.
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('editing updates the name and quote together', (tester) async {
    final state = await pumpSeededApp(tester);
    await openProfile(tester);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    expect(find.text(AppContent.profileEditTitle), findsWidgets);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Paras J');
    await tester.enterText(fields.at(1), 'Small steps win.');
    await tester.tap(find.text(AppContent.profileSaveButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.profile.name, 'Paras J');
    expect(state.profile.personalQuote, 'Small steps win.');
  });

  testWidgets('an empty name is refused', (tester) async {
    final state = await pumpSeededApp(tester);
    final original = state.profile.name;
    await openProfile(tester);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '   ');
    await tester.tap(find.text(AppContent.profileSaveButton));
    await tester.pumpAndSettle();

    expect(find.text(AppContent.profileNameRequired), findsOneWidget);
    expect(state.profile.name, original, reason: 'nothing should be saved');
  });

  testWidgets('the edited name persists across a reload', (tester) async {
    await pumpSeededApp(tester);
    await openProfile(tester);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Renamed');
    await tester.tap(find.text(AppContent.profileSaveButton));
    await tester.pumpAndSettle();

    final reloaded = await reopen();
    expect(reloaded.profile.name, 'Renamed');
  });
}
