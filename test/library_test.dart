import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/content/habit_library.dart';
import 'package:rewiremind/models/habit_preset.dart';
import 'package:rewiremind/screens/habit_library_screen.dart';
import 'package:rewiremind/theme/app_icons.dart';
import 'package:rewiremind/theme/app_theme.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openLibrary(WidgetTester tester) async {
    await openHabitLibrary(tester);
  }

  /// The category strip scrolls, so later categories must be dragged into
  /// view before they can be tapped.
  Future<void> selectCategory(
    WidgetTester tester,
    HabitCategory category,
  ) async {
    final label = HabitLibrary.labels[category]!;

    // Back to the left-hand end first, so the search below always runs in one
    // direction. Without this, picking a late chip and then an early one sends
    // `dragUntilVisible` hunting further right for something behind it.
    await tester.drag(find.byKey(categoryBarKey), const Offset(900, 0));
    await tester.pumpAndSettle();

    final chip = find.text(label);
    // The strip is lazy, so a chip off its right-hand end has to be dragged
    // into existence — but the early ones are already there, and dragging for
    // those would scroll straight past them.
    if (chip.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        chip,
        find.byKey(categoryBarKey),
        const Offset(-140, 0),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(chip.first);
    await tester.pumpAndSettle();
  }

  group('catalogue integrity', () {
    test('every category has presets, a label, an icon and a blurb', () {
      for (final category in HabitLibrary.order) {
        expect(HabitLibrary.labels[category], isNotNull, reason: '$category');
        expect(HabitLibrary.icons[category], isNotNull, reason: '$category');
        expect(HabitLibrary.blurbs[category], isNotNull, reason: '$category');
        expect(
          HabitLibrary.forCategory(category),
          isNotEmpty,
          reason: '$category',
        );
      }
    });

    test('every preset icon key resolves to a glyph and theme colours', () {
      final colors = RewireMindTheme.forest.colors;
      for (final category in HabitCategory.values) {
        for (final preset in HabitLibrary.forCategory(category)) {
          // A missing key silently falls back, which would look wrong rather
          // than crash — so assert the key is actually registered.
          expect(
            AppIcons.forKey(preset.iconKey),
            isNot(Icons.check_circle_outline),
            reason:
                '${preset.name} has an unregistered icon "${preset.iconKey}"',
          );
          expect(
            colors.accents.containsKey(preset.iconKey),
            isTrue,
            reason: '${preset.name} has no accent for "${preset.iconKey}"',
          );
        }
      }
    });

    test('every preset has a positive goal', () {
      for (final category in HabitCategory.values) {
        for (final preset in HabitLibrary.forCategory(category)) {
          expect(preset.target, greaterThan(0), reason: preset.name);
          expect(preset.name.trim(), isNotEmpty);
        }
      }
    });

    test('the editor icon picker keys are all registered', () {
      final colors = RewireMindTheme.forest.colors;
      for (final key in AppIcons.habitKeys) {
        expect(colors.accents.containsKey(key), isTrue, reason: key);
      }
    });
  });

  group('habit library screen', () {
    testWidgets('the + button opens the library, not the raw form', (
      tester,
    ) async {
      await pumpSeededApp(tester);
      await openLibrary(tester);

      expect(find.text(HabitLibrary.screenTitle), findsOneWidget);
      expect(find.text(HabitLibrary.customButton), findsOneWidget);
      // A known Popular preset is listed.
      expect(find.text('Sleep'), findsOneWidget);
    });

    testWidgets('quick-add creates the habit with the preset goal', (
      tester,
    ) async {
      final state = await pumpSeededApp(tester);
      await openLibrary(tester);

      final row = find.ancestor(
        of: find.text('Sleep'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.add)),
      );
      await tester.pumpAndSettle();

      final added = state.habits.firstWhere((h) => h.name == 'Sleep');
      expect(added.target, 8);
      expect(added.unit, 'hours');
      expect(added.iconKey, 'sleep');
      expect(state.habits.length, 7);
      await letToastPass(tester);
    });

    testWidgets('an already-added preset shows as Added and cannot re-add', (
      tester,
    ) async {
      final state = await pumpSeededApp(tester);
      await openLibrary(tester);

      final row = find.ancestor(
        of: find.text('Sleep'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: row.first, matching: find.byIcon(Icons.add)),
      );
      await tester.pumpAndSettle();

      expect(find.text(HabitLibrary.added), findsWidgets);
      expect(state.habits.where((h) => h.name == 'Sleep').length, 1);
      await letToastPass(tester);
    });

    testWidgets('switching category swaps the list', (tester) async {
      await pumpSeededApp(tester);
      await openLibrary(tester);

      expect(find.text('Sleep'), findsOneWidget);

      await selectCategory(tester, HabitCategory.quit);

      expect(tester.takeException(), isNull);
      expect(find.text('Less smoking'), findsOneWidget);
      expect(find.text('Sleep'), findsNothing);
    });

    testWidgets('every category renders without layout errors', (tester) async {
      await pumpSeededApp(tester);
      await openLibrary(tester);

      for (final category in HabitCategory.values) {
        await selectCategory(tester, category);
        expect(tester.takeException(), isNull, reason: '$category');
      }
    });

    testWidgets('tapping a row opens the editor prefilled from the preset', (
      tester,
    ) async {
      await pumpSeededApp(tester);
      await openLibrary(tester);

      await tester.tap(find.text('Sleep'));
      await tester.pumpAndSettle();

      expect(find.text(AppContent.editorNewTitle), findsOneWidget);
      // Name and goal arrive prefilled.
      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.controller?.text, 'Sleep');
      expect(find.text('hours'), findsWidgets);
    });

    testWidgets('Custom habit opens an empty editor', (tester) async {
      await pumpSeededApp(tester);
      await openLibrary(tester);

      await tester.tap(find.text(HabitLibrary.customButton));
      await tester.pumpAndSettle();

      expect(find.text(AppContent.editorNewTitle), findsOneWidget);
      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.controller?.text, isEmpty);
    });
  });
}
