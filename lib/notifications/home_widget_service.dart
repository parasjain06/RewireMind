import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../content/widget_content.dart';

/// Every widget the app offers: the mascot in three sizes, then today's
/// checklist, this week and this month.
///
/// One Android provider each: the picker's list *is* the list of providers, so
/// offering a choice means declaring one per choice. The mascot sizes share
/// one binding routine, and the three views share another.
enum WidgetKind {
  strip('RewireMindStripWidgetProvider'),
  small('RewireMindSmallWidgetProvider'),
  medium('RewireMindWidgetProvider'),
  list('RewireMindListWidgetProvider'),
  week('RewireMindWeekWidgetProvider'),
  month('RewireMindMonthWidgetProvider');

  const WidgetKind(this.provider);

  /// The receiver's class name, which is how Android knows which to place.
  final String provider;
}

/// Keeps the Android home screen widget in step with the app.
///
/// Deliberately thin. Everything the widget shows is decided in [faceFor] —
/// which is ordinary Dart with no plugin in it and so can be tested — and this
/// class only writes the result out and asks Android to redraw.
class HomeWidgetService {
  HomeWidgetService({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  /// The line currently on the widget, so the next update can pick another.
  String? _showing;

  /// The time of day the widget was last told about, or null if never.
  ///
  /// Here for the tests. Whether the widget keeps up with the theme cannot be
  /// checked from the outside — `home_widget` writes to a platform this suite
  /// does not have — so what is checkable is that the app *told* it, and that
  /// it told it the new phase rather than the old one.
  String? lastPhase;

  /// The checklist and calendar data last written, for the same reason.
  String? lastList;
  String? lastCalendar;

  /// Turned off under `flutter test`, where there is no platform to write to.
  static bool available = true;

  /// Whether this platform has a home screen widget to offer at all.
  ///
  /// Android only. The widget is Android RemoteViews drawn from Kotlin; an
  /// iPhone widget would be a separate WidgetKit extension written in Swift,
  /// and until one exists the screens that offer a widget are hidden there
  /// rather than promising something that cannot be added.
  static bool get supported => defaultTargetPlatform == TargetPlatform.android;

  /// Works out what the widget should say and puts it there.
  Future<void> push({
    required int streak,
    required int pathLength,
    required int scheduledToday,
    required int doneToday,
    required int daysSinceSeen,
    required String phase,
    required bool hasHabits,
    int? challengeDay,
    String? name,
    bool followsClock = true,
    String? todayList,
    String? calendar,
    int streakDays = 0,
  }) async {
    lastPhase = phase;
    lastList = todayList;
    lastCalendar = calendar;

    final percent = scheduledToday == 0
        ? 0
        : ((doneToday / scheduledToday) * 100).round().clamp(0, 100);

    final face = faceFor(
      streak: streak,
      pathLength: pathLength,
      scheduledToday: scheduledToday,
      doneToday: doneToday,
      daysSinceSeen: daysSinceSeen,
      hasHabits: hasHabits,
      phase: phase,
      challengeDay: challengeDay,
      name: name,
      avoid: _showing,
      rng: _rng,
    );
    _showing = face.line;

    if (!available) return;
    try {
      await HomeWidget.saveWidgetData<String>('wm_line', face.line);
      await HomeWidget.saveWidgetData<String>('wm_line_short', face.shortLine);
      // The whole pool as well as the one line. The widget turns over its own
      // copy every hour out of this, which is what keeps it from going stale
      // between one launch of the app and the next.
      await HomeWidget.saveWidgetData<String>('wm_lines', face.lines);
      await HomeWidget.saveWidgetData<String>(
        'wm_lines_short',
        face.linesShort,
      );
      await HomeWidget.saveWidgetData<String>('wm_sub', face.sub);
      await HomeWidget.saveWidgetData<String>('wm_streak', face.streak);
      await HomeWidget.saveWidgetData<String>(
        'wm_streak_short',
        face.streakShort,
      );
      await HomeWidget.saveWidgetData<String>('wm_mood', face.mood.name);
      await HomeWidget.saveWidgetData<int>('wm_progress', percent);
      // Which sky, sun or moon and tree to draw behind it — the same three
      // the app paints its own header with.
      await HomeWidget.saveWidgetData<String>('wm_phase', phase);
      // Whether that phase is pinned. While it follows the clock, the widget
      // works the phase out itself at each redraw, so the evening sky arrives
      // in the evening rather than whenever the app is next opened.
      await HomeWidget.saveWidgetData<String>(
        'wm_clock',
        followsClock ? '1' : '0',
      );
      if (todayList != null) {
        await HomeWidget.saveWidgetData<String>('wm_list', todayList);
      }
      if (calendar != null) {
        await HomeWidget.saveWidgetData<String>('wm_cal', calendar);
      }
      await HomeWidget.saveWidgetData<int>('wm_streak_days', streakDays);
      // Every size, not just the one we think is placed: they read the same
      // data, and a stale card is worse than no card whichever size it is.
      for (final kind in WidgetKind.values) {
        await HomeWidget.updateWidget(
          name: kind.provider,
          androidName: kind.provider,
        );
      }
    } catch (_) {
      // A phone with no widget placed, or a launcher that refuses: the app
      // carries on either way. Nothing here is worth interrupting a check-in.
    }
  }

  /// Offers to pin a given widget to the home screen.
  ///
  /// Android decides whether the launcher supports this at all, so a `false`
  /// means "ask them to do it by hand", not "something went wrong".
  static Future<bool> requestPin(WidgetKind kind) async {
    if (!available) return false;
    try {
      final pinned = await _channel.invokeMethod<bool>('pin', {
        'provider': kind.provider,
      });
      return pinned ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Our own channel rather than `home_widget`'s `requestPinWidget`.
  ///
  /// The plugin makes the request and returns, which tells us it was asked and
  /// nothing about whether anything was placed. The platform side here passes
  /// Android a success callback, so that the moment a widget is actually on
  /// the home screen the app can get out of the way and let it be seen —
  /// otherwise you tap Add and are handed back to a settings page with no sign
  /// anything happened.
  static const _channel = MethodChannel('com.parasjain.rewiremind/widgets');

  /// The widget that has just been placed on the home screen, as Android
  /// reports it. Listened to by the shell, which says so and goes Home.
  static final ValueNotifier<WidgetKind?> pinned = ValueNotifier(null);

  /// Starts listening for Android's word that a widget landed. Once.
  static void listenForPins() {
    if (!available) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'pinned') return;
      final provider = call.arguments as String?;
      WidgetKind? kind;
      for (final k in WidgetKind.values) {
        if (k.provider == provider) kind = k;
      }
      // Set to null first so the same widget added twice still notifies.
      pinned.value = null;
      pinned.value = kind ?? WidgetKind.medium;
    });
  }

  /// What the widget should show, given the state of the day.
  ///
  /// Pure, and the whole of the behaviour: the mood ladder runs from a day
  /// finished, through a day started, to a day untouched, to somebody who has
  /// not opened the app in a while — and only that last rung is sad.
  static WidgetFace faceFor({
    required int streak,
    required int pathLength,
    required int scheduledToday,
    required int doneToday,
    required int daysSinceSeen,
    bool hasHabits = true,
    // [DayPhase.name]. Chooses both the character and, on an untouched day,
    // which set of lines it gets to say.
    String phase = 'day',
    // Where the 21 days are up to, or null when the challenge is not running.
    int? challengeDay,
    String? name,
    String? avoid,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final left = (scheduledToday - doneToday).clamp(0, scheduledToday);
    final chip = WidgetContent.chip(
      doneToday: doneToday,
      scheduledToday: scheduledToday,
    );
    final sub = WidgetContent.sub(
      challengeDay: challengeDay,
      pathLength: pathLength,
      streak: streak,
      total: scheduledToday,
    );

    // Two clear days with nothing logged. Not one: a single missed day is a
    // normal week, and a character that sulks over one is a character you
    // stop believing.
    final (pool, mood) = switch (0) {
      // Nothing tracked at all comes first, ahead of the missed-days rung:
      // somebody with no habits has not missed anything.
      _ when !hasHabits => (WidgetContent.firstRun, WidgetMood.nudge),
      _ when daysSinceSeen >= 2 => (WidgetContent.missed(name), WidgetMood.sad),
      _ when scheduledToday > 0 && left == 0 => (
        WidgetContent.done,
        WidgetMood.happy,
      ),
      _ when doneToday > 0 => (WidgetContent.partway, WidgetMood.nudge),
      _ => (WidgetContent.waitingFor(phase), WidgetMood.nudge),
    };

    final line = WidgetContent.pick(pool, avoid, r);
    return WidgetFace(
      line: line.long,
      shortLine: line.short,
      sub: sub,
      streak: chip.long,
      streakShort: chip.short,
      mood: mood,
      pool: pool,
    );
  }
}
