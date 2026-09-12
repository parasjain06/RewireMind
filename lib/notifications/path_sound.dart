import 'package:audioplayers/audioplayers.dart';

/// The app's sounds, all two of them.
///
/// One carries the signal on the once-a-day walk up the 21-day path; the other
/// marks the moment the last habit of the day is done. Nothing else makes a
/// noise, deliberately: an app that chirps at every tap teaches you to turn
/// the volume off, and then it has nothing left to say when something
/// actually happens.
///
/// There used to be a second, a click as the signal landed. One sound for the
/// whole movement says it better — the chime runs exactly as long as the
/// climb, so it already ends on the arrival.
///
/// It follows the media volume rather than the notification channel, because
/// this is a sound made by a screen somebody is looking at, not a message
/// arriving from somewhere else.
class PathSound {
  const PathSound._();

  /// Turned off under `flutter test`, where there is no audio platform to
  /// write to and an unguarded call throws MissingPluginException on the
  /// first frame.
  static bool available = true;

  /// How many times the chime has been asked for.
  ///
  /// Here for the tests: whether a sound left the speaker is not something a
  /// widget test can see, but whether it was asked for at the right moment is
  /// exactly the thing worth pinning.
  static int travels = 0;

  /// How many times the day-closed check has been asked for. For the tests.
  static int closes = 0;

  static AudioPlayer? _player;

  /// Its own player: the day can close while the path's chime is still
  /// ringing, and one should not cut the other off.
  static AudioPlayer? _closer;

  /// The last habit of the day, done. A short, clean check that lands with
  /// the celebration.
  static Future<void> closeDay() async {
    closes++;
    if (!available) return;
    try {
      final player = _closer ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource('audio/day_closed.mp3'));
    } catch (_) {
      // No sound, then; the celebration plays either way.
    }
  }

  /// The signal setting off up the fibre. Soft, and as long as the climb.
  ///
  /// Silence is a perfectly good outcome: a phone on silent, a device with no
  /// audio route, a codec the platform will not open. None of those are worth
  /// interrupting an animation over, so every failure is swallowed and the
  /// walk finishes either way.
  static Future<void> travel() async {
    travels++;
    if (!available) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.setAudioContext(ChallengeMusic._mix);
      // Restarted rather than queued: a second walk while the first is still
      // ringing should replace it, not stack on top of it.
      await player.stop();
      await player.play(AssetSource('audio/path_travel.mp3'));
    } catch (_) {
      // No sound, then.
    }
  }

  /// Releases the player. Called when the path screen goes away, so an idle
  /// audio session is not held open for the life of the app.
  static Future<void> release() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {
      // Already gone.
    }
  }
}

/// A cheerful loop under the 21-day path, for as long as it is on screen.
///
/// Mixed with other audio rather than taking it over: somebody listening to
/// their own music keeps it, and the path's chime plays over this rather than
/// stopping it. It follows the media volume, and the path screen has a
/// speaker button to turn it off, which is remembered.
class ChallengeMusic {
  const ChallengeMusic._();

  static const double _volume = 0.45;

  static AudioPlayer? _player;

  /// Whether it is meant to be playing: the path screen is open and the music
  /// is on. Here for the tests, like [PathSound.travels].
  static bool playing = false;

  static AudioContext get _mix =>
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  static Future<void> start() async {
    playing = true;
    if (!PathSound.available) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.setAudioContext(_mix);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volume);
      await player.play(AssetSource('audio/challenge_music.wav'));
    } catch (_) {
      // Silence is fine; the path does not need a soundtrack to work.
    }
  }

  /// Off, and the player let go.
  static Future<void> stop() async {
    playing = false;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }

  /// Paused while the app is in the background, and back on its return.
  static Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {}
  }

  static Future<void> resume() async {
    if (!playing) return;
    try {
      await _player?.resume();
    } catch (_) {}
  }

  /// Lowered for [length] under the path's chime, then back up.
  static Future<void> duck(Duration length) async {
    final player = _player;
    if (player == null) return;
    try {
      await player.setVolume(0.12);
      await Future<void>.delayed(length);
      if (_player == player) await player.setVolume(_volume);
    } catch (_) {}
  }
}
