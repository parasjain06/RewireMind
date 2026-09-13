import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../content/notification_content.dart';
import '../models/day_phase.dart';
import 'notification_planner.dart';

/// ============================================================================
/// THE PLATFORM ADAPTER
/// ============================================================================
/// Hands [PlannedSend]s to the operating system, and nothing else. Every
/// decision about *whether* to send lives in [NotificationPlanner]; this file
/// contains no rules, so there is only one place to look when the app says
/// something it should not have.
/// ============================================================================

/// Tests and the widget suite never touch the plugin. Set false to make every
/// method a no-op.
bool notificationsAvailable = !kIsWeb;

/// What the user tapped on a notification.
///
/// Three things can happen to a habit reminder: the notification itself is
/// tapped, which opens that habit on today so the amount can be set; its
/// button is pressed, which adds one step and then opens the same page; or
/// something with no habit behind it is tapped, which just opens the app.
@immutable
class NotificationTap {
  const NotificationTap.open() : habitId = null, addsStep = false;
  const NotificationTap.openHabit(String this.habitId) : addsStep = false;
  const NotificationTap.logStep(String this.habitId) : addsStep = true;

  /// The habit the notification was about, when it was about one.
  final String? habitId;

  /// Whether one step of it should be logged on the way in.
  final bool addsStep;
}

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Raised when a notification action is chosen. The app listens and applies
  /// it — the service itself never touches habit data.
  final StreamController<NotificationTap> _actions =
      StreamController<NotificationTap>.broadcast();

  Stream<NotificationTap> get actions => _actions.stream;

  /// Versioned on purpose. An Android channel's sound, importance and vibration
  /// are frozen the moment it is first created — the OS ignores every later
  /// change, by design, so an app cannot make itself louder behind the user's
  /// back. Changing the tone means shipping a *new* channel id and letting the
  /// old one retire, so the version suffix is what makes that a one-line
  /// change instead of a migration.
  /// v2 because the sound changed.
  ///
  /// A notification channel is immutable once Android has created it: set a
  /// new sound on the same id and nothing happens, for everybody who already
  /// had the app. The only way to change it is to publish a different channel,
  /// which is why this is a version and not a name.
  ///
  /// v3: one channel per kind, so the phone's own settings can quieten habit
  /// reminders, the evening check-in and the user's own reminders separately.
  /// v4: the cheerful reward sound in place of the chime.
  /// v5: the same sound three times over, so it is not missed.
  static const Map<SendKind, (String, String, String)> _channels = {
    SendKind.habit: (
      'rewiremind_habits_v5',
      NotificationContent.channelHabits,
      NotificationContent.channelHabitsBody,
    ),
    SendKind.nudge: (
      'rewiremind_nudge_v5',
      NotificationContent.channelNudge,
      NotificationContent.channelNudgeBody,
    ),
    SendKind.general: (
      'rewiremind_general_v5',
      NotificationContent.channelGeneral,
      NotificationContent.channelGeneralBody,
    ),
  };

  /// The picture on the right of every notification: the app's character,
  /// in `res/drawable-nodpi`, kept through shrinking by `res/raw/keep.xml`.
  static const String _largeIcon = 'ic_notify_mascot';

  /// Marks the payload of a habit reminder, ahead of the habit's id.
  static const String _habitPayload = 'habit:';

  /// The tone, in `android/app/src/main/res/raw`.
  ///
  /// Named without an extension because that is how Android addresses a raw
  /// resource, and referenced from the manifest as well as from here — a
  /// resource named only in Dart is invisible to the build and gets dropped
  /// from the APK, which is how the status-bar icon once took the whole
  /// notification module down with it.
  static const String _sound = 'rewire_reward3';
  static const String _markDoneActionId = 'mark_done';

  /// Android accent colour per phase, so the shade matches the app that the
  /// tap will open. These mirror the phase palettes in `app_theme.dart`.
  static const Map<DayPhase, Color> _accents = {
    DayPhase.earlyMorning: Color(0xFFE8823A),
    DayPhase.day: Color(0xFF3E9CC4),
    DayPhase.night: Color(0xFF4FB86B),
  };

  Future<void> init() async {
    if (!notificationsAvailable || _ready) return;

    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // A device that cannot name its zone still gets reminders, just anchored
      // to UTC. Better than no notifications at all.
    }

    // The status bar tints the small icon by its alpha, so the first choice is
    // the white silhouette — the colour launcher icon arrives as a solid white
    // square. The launcher icon is the fallback, and having one matters more
    // than it looks:
    //
    // an icon name that does not resolve makes `initialize` throw, and because
    // every other call here awaits `init()`, that one bad string took out the
    // whole module. Not just the notifications — the master switch on the
    // settings screen stopped responding at all, because the handler behind it
    // threw before it could change anything. A missing icon should cost a
    // prettier icon, not the feature.
    for (final icon in const [
      // The bare resource name is the form this plugin documents, and the one
      // that actually resolves — '@drawable/…' is accepted by the analyzer and
      // rejected by the platform, which is how a working icon turned into a
      // dead notification module.
      'ic_stat_rewiremind',
      '@mipmap/ic_launcher',
    ]) {
      try {
        await _plugin.initialize(
          settings: InitializationSettings(
            android: AndroidInitializationSettings(icon),
            iOS: const DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
              defaultPresentAlert: true,
              defaultPresentSound: true,
              defaultPresentBadge: true,
            ),
          ),
          onDidReceiveNotificationResponse: _onResponse,
        );
        _ready = true;
        // A tap that started the app, rather than arriving at one already
        // running: the plugin holds it until it is asked for, and without
        // this a reminder opened Home instead of the habit it was about.
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final response = launch?.notificationResponse;
        if (launch?.didNotificationLaunchApp == true && response != null) {
          _onResponse(response);
        }
        // The channels this version replaced. Left in place they would sit
        // in the phone's settings beside the new ones, under the same names
        // and with the old sound.
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        for (final old in const [
          'rewiremind_reminders_v2',
          'rewiremind_habits_v3',
          'rewiremind_nudge_v3',
          'rewiremind_general_v3',
          'rewiremind_habits_v4',
          'rewiremind_nudge_v4',
          'rewiremind_general_v4',
        ]) {
          try {
            await android?.deleteNotificationChannel(channelId: old);
          } catch (_) {}
        }
        return;
      } on PlatformException catch (error) {
        debugPrint('RewireMind: notification icon $icon rejected — $error');
      }
    }

    // Neither icon worked, which should be impossible. Rather than leave every
    // later call throwing into a button handler, the module stands down: the
    // switch will report that notifications are unavailable instead of doing
    // nothing at all.
    notificationsAvailable = false;
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (!payload.startsWith(_habitPayload)) {
      _actions.add(const NotificationTap.open());
      return;
    }
    final id = payload.substring(_habitPayload.length);
    _actions.add(
      response.actionId == _markDoneActionId
          ? NotificationTap.logStep(id)
          : NotificationTap.openHabit(id),
    );
  }

  /// Asks for permission, returning whether we ended up with it.
  ///
  /// Android 13+ and iOS both prompt; older Android grants implicitly.
  ///
  /// Two things here are not obvious and both of them broke the switch on a
  /// phone that had already said yes:
  ///
  ///   * asking for a permission you already hold answers `null` on Android,
  ///     which arrives here as "denied" — so the master switch could never be
  ///     turned on by somebody whose permission was never in doubt. Held is
  ///     checked first, and nothing is asked;
  ///   * the answer to the prompt is not to be trusted either. Some builds
  ///     return null whatever the user pressed, so what is reported back is
  ///     what the system says afterwards, not what the call returned.
  Future<bool> requestPermission() async {
    if (!notificationsAvailable) return false;
    await init();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      if (await android.areNotificationsEnabled() == true) return true;
      final asked = await android.requestNotificationsPermission();
      return asked ?? await hasPermission();
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final asked = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return asked ?? await hasPermission();
    }
    return false;
  }

  Future<bool> hasPermission() async {
    if (!notificationsAvailable) return false;
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return true;
  }

  /// Replaces everything pending with [sends].
  ///
  /// Cancelling first is what keeps a stale reminder from arriving after the
  /// user has already ticked the habit it was chasing — the planner reruns on
  /// every mutation, and this is where its verdict takes effect.
  Future<void> reschedule(List<PlannedSend> sends) async {
    if (!notificationsAvailable) return;
    await init();

    await _plugin.cancelAll();

    for (final send in sends) {
      await _plugin.zonedSchedule(
        id: send.id,
        title: send.title,
        body: send.body,
        scheduledDate: tz.TZDateTime.from(send.at, tz.local),
        notificationDetails: _detailsFor(send),
        payload: _payloadFor(send),
        // Inexact on purpose: a habit reminder landing at 08:34 instead of
        // 08:30 is fine, and exact alarms need a permission prompt that reads
        // as hostile for something this ordinary.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!notificationsAvailable) return;
    await init();
    await _plugin.cancelAll();
  }

  /// Posts a notification immediately. Used by the settings screen's preview,
  /// so the user can see and hear one before committing to a schedule.
  Future<void> showNow(PlannedSend send, {int id = 0}) async {
    if (!notificationsAvailable) return;
    await init();
    await _plugin.show(
      id: id,
      title: send.title,
      body: send.body,
      notificationDetails: _detailsFor(send),
      payload: _payloadFor(send),
    );
  }

  String? _payloadFor(PlannedSend send) =>
      send.habitId == null ? null : '$_habitPayload${send.habitId}';

  NotificationDetails _detailsFor(PlannedSend send) {
    final (id, name, description) = _channels[send.kind]!;
    final nudge = send.kind == SendKind.nudge && send.lines.isNotEmpty;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(_sound),
        color: _accents[send.phase],
        colorized: false,
        largeIcon: const DrawableResourceAndroidBitmap(_largeIcon),
        // The small line beside the app's name: which habit, or which
        // evening send, so the notification says what it is at a glance.
        subText: send.label,
        groupKey: 'rewiremind',
        // The evening send expands into what is still to do, with the count
        // as its last line; everything else expands to its full sentence.
        //
        // No progress bar: Android gives the bar the line the body would have
        // had, so the sentence we wrote never reached the screen — and the
        // style's own summary line is not drawn on every phone either. The
        // count is a line of the list instead, where it is always shown.
        styleInformation: nudge
            ? InboxStyleInformation(
                [
                  for (final line in send.lines.take(4)) '○  $line',
                  if (send.done > 0)
                    NotificationContent.nudgeSummary(send.done, send.total),
                ],
                contentTitle: send.title,
                summaryText: NotificationContent.nudgeSummary(
                  send.done,
                  send.total,
                ),
              )
            : BigTextStyleInformation(send.body),
        actions: send.canMarkDone && send.quickLabel != null
            ? [
                AndroidNotificationAction(
                  _markDoneActionId,
                  send.quickLabel!,
                  // Opens the app on the habit it logged: the one place where
                  // the amount is certain to be right, and seen to be. A
                  // button that wrote from the shade would have to guess at
                  // what else had been drunk since the app last looked.
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        subtitle: send.label,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      ),
    );
  }

  void dispose() => _actions.close();
}
