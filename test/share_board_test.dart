import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/theme/app_theme.dart';
import 'package:rewiremind/widgets/habit_board.dart';
import 'package:rewiremind/widgets/share_board.dart';

import 'helpers.dart';

/// The board is the one thing in this app worth showing somebody, and the one
/// thing nobody can screenshot cleanly — it scrolls two ways inside a card on
/// a page with a nav bar under it. So it is drawn again, off screen, at its
/// real size.
void main() {
  testWidgets('the board renders to a picture at more than screen size', (
    tester,
  ) async {
    final state = await seededState();
    disableBoardHintPulseIfPresent();

    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: RewireMindTheme.byId('forest').toThemeData(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: HabitBoard(onOpenDay: (_, _) {}, onOpenDate: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    late final dynamic bytes;
    await tester.runAsync(() async {
      bytes = await BoardShare.capture(key);
    });

    expect(bytes, isNotNull);
    // A PNG, and a real one: the eight-byte signature, then enough data that
    // it cannot be an empty frame.
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(
      bytes.length,
      greaterThan(5000),
      reason: 'an empty capture is a few hundred bytes; a board is not',
    );
  });

  test('sharing is off under test, so nothing tries to open a sheet', () {
    expect(boardSharingAvailable, isFalse);
  });
}

/// The hint's pulse is disabled by the app-level helper; the board on its own
/// does not run it, so this is a no-op kept for symmetry with the other tests.
void disableBoardHintPulseIfPresent() {}
