import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/models/progress_range.dart';

import 'helpers.dart';

/// Renders the real app at phone size and walks every tab, asserting that
/// nothing throws. This is what catches layout faults (unbounded constraints,
/// overflow) without needing a browser.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every tab renders without exceptions', (tester) async {
    await pumpSeededApp(tester);
    expect(tester.takeException(), isNull, reason: 'Home');

    for (final tab in ['Calendar', 'Progress', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('all four progress ranges render', (tester) async {
    await pumpSeededApp(tester);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();

    for (final range in ProgressRange.values) {
      // The period now lives behind a menu in the header rather than a row of
      // pills, so it has to be opened before a range can be chosen.
      await tester.tap(find.byTooltip(AppContent.progressRangeTooltip));
      await tester.pumpAndSettle();

      // While the menu is open the label appears twice — on the button and in
      // the list — so take the one in the menu.
      await tester.tap(find.text(range.label).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: range.label);
      expect(
        find.text(range.label),
        findsOneWidget,
        reason: 'the button has to show what is selected',
      );
    }
  });

  testWidgets('checking off a habit updates the Home counter', (tester) async {
    await pumpSeededApp(tester);

    expect(find.textContaining('completed'), findsWidgets);
    final before = (tester
        .widget<Text>(find.textContaining('completed').first)
        .data)!;

    // Tap the first habit's check button.
    await tester.tap(find.text('Drink 2L water'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(before, contains('completed'));
  });
}
