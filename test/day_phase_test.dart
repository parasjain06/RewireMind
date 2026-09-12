import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/models/day_phase.dart';
import 'package:rewiremind/theme/app_theme.dart';

import 'helpers.dart';

import 'package:rewiremind/widgets/illustrations.dart';

/// The header scene changes with the clock, so the mapping from hour to phase
/// needs to be exact at the boundaries and every phase has to paint without
/// throwing — a CustomPainter failure would blank the whole header.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('phase for the hour', () {
    DayPhase at(int hour) => DayPhase.of(DateTime(2026, 9, 5, hour));

    test('boundaries land on the right phase', () {
      expect(at(0), DayPhase.night);
      expect(at(4), DayPhase.night);
      expect(at(5), DayPhase.earlyMorning, reason: 'early morning starts at 5');
      expect(at(9), DayPhase.earlyMorning);
      expect(at(10), DayPhase.day, reason: 'day starts at 10');
      expect(at(18), DayPhase.day);
      expect(at(19), DayPhase.night, reason: 'night starts at 19');
      expect(at(23), DayPhase.night);
    });

    test('every hour of the day maps to some phase', () {
      for (var h = 0; h < 24; h++) {
        expect(at(h), isNotNull, reason: 'hour $h');
      }
    });
  });

  testWidgets('every phase paints without throwing', (tester) async {
    for (final phase in DayPhase.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: RewireMindTheme.forest.toThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TreeScene(height: 128, treeX: 0.76, phase: phase),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: phase.name);
    }
  });

  testWidgets('the scene follows the clock when no phase is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RewireMindTheme.forest.toThemeData(),
        home: const Scaffold(
          body: SizedBox(width: 360, child: TreeScene(height: 128)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final scene = tester.widget<TreeScene>(find.byType(TreeScene));
    expect(scene.phase, isNull, reason: 'null means follow the clock');
  });

  group('the palette follows the phase', () {
    test('every phase has its own background, and night inverts', () {
      final base = RewireMindTheme.forest;
      final byPhase = {for (final p in DayPhase.values) p: base.forPhase(p)};

      final backgrounds = byPhase.values
          .map((t) => t.colors.backgroundGradient.first)
          .toSet();
      expect(
        backgrounds.length,
        DayPhase.values.length,
        reason: 'each time of day needs a distinct sky, not one shared tint',
      );

      final night = byPhase[DayPhase.night]!;
      expect(night.brightness, Brightness.dark);
      expect(
        night.colors.textPrimary.computeLuminance(),
        greaterThan(night.colors.surface.computeLuminance()),
        reason: 'night text must be lighter than the card it sits on',
      );
      // The typography bakes in its colours, so it has to be re-derived or the
      // whole page would keep daytime ink on a dark background.
      expect(night.text.cardTitle.color, night.colors.textPrimary);

      for (final day in [DayPhase.earlyMorning, DayPhase.day]) {
        expect(byPhase[day]!.brightness, Brightness.light, reason: day.name);
      }
    });

    test('a theme without phases is simply left alone', () {
      final static_ = RewireMindTheme.forest.copyWith(id: 'plain');
      // copyWith carries phases over, so clear them the way a new preset would
      // by never supplying them.
      final plain = RewireMindTheme(
        id: 'plain',
        name: 'Plain',
        brightness: Brightness.light,
        colors: static_.colors,
        text: static_.text,
      );
      for (final p in DayPhase.values) {
        expect(identical(plain.forPhase(p), plain), isTrue, reason: p.name);
      }
    });
  });

  group('the whole app follows the pinned phase', () {
    testWidgets('every phase repaints the page, not just the header', (
      tester,
    ) async {
      disableLivePhaseTicker();
      final state = await emptyState();

      final skies = <Color>{};
      for (final phase in DayPhase.values) {
        await state.setFixedPhase(phase);
        expect(state.activePhase, phase);
        expect(state.followsClock, isFalse);
        skies.add(state.theme.colors.backgroundGradient.first);
      }

      expect(
        skies.length,
        DayPhase.values.length,
        reason: 'the page background, not just the header, has to change',
      );

      await state.setFixedPhase(null);
      expect(state.followsClock, isTrue);
    });

    testWidgets('night renders the app without layout errors', (tester) async {
      final state = await emptyState();
      await state.setFixedPhase(DayPhase.night);
      await pumpAppWith(tester, state);
      expect(tester.takeException(), isNull);
      expect(state.theme.brightness, Brightness.dark);
    });
  });
}
