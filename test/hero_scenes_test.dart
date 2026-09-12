import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/app_content.dart';
import 'package:rewiremind/models/day_phase.dart';
import 'package:rewiremind/screens/home_screen.dart';

/// The header's scenes are named by string, and a mistyped one fails silently
/// at runtime as a grey box on the home page — the one screen every session
/// starts on. Cheaper to catch here.
void main() {
  test('every phase has a run of scenes', () {
    for (final phase in DayPhase.values) {
      expect(kHeroScenes[phase], isNotEmpty, reason: phase.name);
    }
  });

  test('every clip a scene names is actually shipped', () {
    for (final entry in kHeroScenes.entries) {
      for (final scene in entry.value) {
        for (final asset in [scene.asset, scene.left]) {
          if (asset == null) continue;
          expect(
            File(asset).existsSync(),
            isTrue,
            reason: '${entry.key.name} / ${scene.label}: $asset',
          );
        }
      }
    }
  });

  test('everything the brain says fits its bubble', () {
    // The bubble sits between the quote and the tree; past about four words
    // a line wraps into the tree.
    final lines = [
      for (final scenes in kHeroScenes.values)
        for (final scene in scenes) ...scene.says,
      for (final (done, total, streak) in [(0, 5, 0), (2, 5, 12), (5, 5, 30)])
        ...AppContent.heroAboutYou(
          done: done,
          total: total,
          streak: streak,
          hasHabits: true,
        ),
    ];
    for (final line in lines) {
      expect(line.length, lessThanOrEqualTo(22), reason: line);
    }
  });

  test('what it says about your day is true', () {
    List<String> say(int done, int total, {int streak = 0}) =>
        AppContent.heroAboutYou(
          done: done,
          total: total,
          streak: streak,
          hasHabits: true,
        );

    expect(say(0, 4), contains('4 to go today!'));
    expect(say(3, 4), containsAll(['3 down, 1 to go!', 'Just one left!']));
    expect(say(4, 4), contains('All done! 🎉'));
    expect(say(4, 4).any((l) => l.contains('to go')), isFalse);
    expect(say(1, 4, streak: 12), contains('12-day streak! 🔥'));
    expect(say(1, 4, streak: 1).any((l) => l.contains('streak')), isFalse);
    expect(
      AppContent.heroAboutYou(done: 0, total: 0, streak: 0, hasHabits: false),
      contains('Add a habit?'),
    );
  });

  /// The bug this guards: a scene held for longer than its clip runs loops
  /// back into itself, so the last stretch of it is the opening again — the
  /// coffee machine turning up a second time after the cup had been drunk.
  test('every scene is held for exactly as long as its clip runs', () {
    for (final entry in kHeroScenes.entries) {
      for (final scene in entry.value) {
        final clip = webpMillis(scene.asset);
        final where = '${entry.key.name} / ${scene.label}';

        if (scene.crosses) {
          // One length of the strip per play of the walk cycle, out and back.
          expect(
            scene.millis % clip,
            0,
            reason: '$where: $clip ms of clip, ${scene.millis} ms of scene',
          );
        } else {
          expect(scene.millis, clip, reason: where);
        }
        // A crossing scene splits its beat in two, so an odd one would leave
        // the return leg a millisecond short of the clip.
        expect(scene.millis.isEven, isTrue, reason: where);
      }
    }
  });
}

/// How long an animated WebP runs, by summing its frames' own durations.
///
/// Read from the file rather than trusted from a constant: the point of the
/// test is that what ships and what the code claims cannot drift apart.
int webpMillis(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var at = 12; // past 'RIFF', the file size, and 'WEBP'
  var total = 0;

  while (at + 8 <= bytes.length) {
    final tag = String.fromCharCodes(bytes, at, at + 4);
    final size = data.getUint32(at + 4, Endian.little);
    if (tag == 'ANMF') {
      // The frame header: x, y, width, height, then a 24-bit duration.
      final d = at + 8 + 12;
      total +=
          data.getUint8(d) |
          (data.getUint8(d + 1) << 8) |
          (data.getUint8(d + 2) << 16);
    }
    at += 8 + size + (size & 1); // chunks are padded to an even length
  }
  return total;
}
