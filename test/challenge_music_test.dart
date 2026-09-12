import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/notifications/path_sound.dart';
import 'package:rewiremind/screens/roadmap_screen.dart';

import 'helpers.dart';

/// The 21-day path has music while it is open, and only then.
void main() {
  testWidgets('plays on the path, stops on leaving, and can be muted', (
    tester,
  ) async {
    final state = await seededState();
    await pumpAppWith(tester, state);
    expect(ChallengeMusic.playing, isFalse);

    RoadmapScreen.open(tester.element(find.byType(Scaffold).first));
    // The path animates for ever, so it never settles: step the clock.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(ChallengeMusic.playing, isTrue, reason: 'on arrival');

    // The speaker turns it off, and the choice is kept.
    await tester.tap(find.byTooltip(AppContent.musicOff));
    await tester.pump(const Duration(milliseconds: 300));
    expect(ChallengeMusic.playing, isFalse);
    expect(state.challengeMusicOn, isFalse);

    await tester.tap(find.byTooltip(AppContent.musicOn));
    await tester.pump(const Duration(milliseconds: 300));
    expect(ChallengeMusic.playing, isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back).last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(ChallengeMusic.playing, isFalse, reason: 'off the path, silent');
  });
}
