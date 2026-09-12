import 'package:flutter/foundation.dart';

/// ============================================================================
/// NOTIFICATION COPY
/// ============================================================================
/// The words the app supplies itself: the rotating quote, the token system
/// that fills a user's reminder in with live data, and the settings screen's
/// own labels.
///
/// The reminders themselves are written by the user; ready-made wording lives
/// in `reminder_library.dart`.
/// ============================================================================

/// The live figures a reminder's tokens are filled in from.
@immutable
class ReminderFacts {
  const ReminderFacts({
    required this.firstPending,
    required this.pending,
    required this.done,
    required this.total,
    required this.streak,
    required this.name,
    required this.quote,
  });

  final String firstPending;
  final int pending;
  final int done;
  final int total;
  final int streak;
  final String name;
  final String quote;
}

class NotificationContent {
  const NotificationContent._();

  /// The three categories, as the phone's own notification settings list
  /// them — so each can be quietened on its own.
  static const String channelHabits = 'Habit reminders';
  static const String channelHabitsBody = 'Reminders tied to one habit.';
  static const String channelNudge = 'Evening check-in';
  static const String channelNudgeBody =
      'One nudge in the evening, if today is not done.';
  static const String channelGeneral = 'Your reminders';
  static const String channelGeneralBody = 'Reminders you wrote yourself.';

  /// Beside the app's name at the top of the evening send.
  // Short: the shade puts this beside the app's name and cuts it at about a
  // dozen characters, so anything longer is read as an ellipsis.
  static const String nudgeLabel = 'Check-in';
  static String challengeLabel(int day, int length) => 'Day $day/$length';

  /// Under the list in the expanded evening send.
  static String nudgeSummary(int done, int total) => '$done of $total done';

  /// The one button: on a habit reminder, for that habit.
  static const String actionMarkDone = 'Mark done';

  /// One step of a measured habit, on the reminder's button.
  static String actionAdd(String step) => '+$step';

  // -- quotes ---------------------------------------------------------------

  /// Short on purpose. A notification is read at a glance, half-awake, from a
  /// lock screen — anything that needs a second line has already lost.
  static const List<String> quotes = [
    'Small steps become a life.',
    'One percent. Every day.',
    'Showing up is the whole trick.',
    'Future you is watching. 👀',
    'Start before you feel ready.',
    'Boring days build big things.',
    'Nobody is watching. That is the point.',
    'Consistency beats intensity.',
    'Do it badly. Just do it.',
    'Today is one rep.',
    'Bad days count double.',
    'You are one tick from a good day.',
  ];

  /// One quote per day, stable for the whole day.
  static String quoteFor(DateTime day) =>
      quotes[_daysSinceEpoch(day) % quotes.length];

  // -- the habit placeholder -----------------------------------------------

  /// Stand-in for a habit's name inside a preset.
  ///
  /// Never seen by the user: the picker substitutes the real name before
  /// the wording ever reaches the editor, so nobody types a brace.
  static const String habitPlaceholder = '{habit}';

  static String forHabit(String text, String habitName) =>
      text.replaceAll(habitPlaceholder, habitName);

  // -- the daily catch-up ---------------------------------------------------

  /// The one message the app writes itself.
  ///
  /// A live streak and an unlogged day are the same fact, so this is a single
  /// notification whose wording changes rather than two that would always
  /// arrive together. Rotates by the day so it does not become wallpaper.
  static String catchUpTitle({required int streak, required int pending}) {
    if (streak >= 2) return 'Keep your $streak-day streak 🔥';
    return pending == 1 ? 'One habit left today' : '$pending habits left today';
  }

  static String catchUpBody({
    required int streak,
    required int pending,
    required String firstPending,
    DateTime? day,
  }) {
    final what = pending == 1
        ? '$firstPending is still to do.'
        : '$firstPending and ${pending - 1} more still to do.';
    const lines = [
      'A few minutes is all it takes.',
      'Finish strong tonight.',
      'Done it already? Tap to tick it off.',
    ];
    return '$what ${_pick(lines, day)}';
  }

  /// Rotates a line by the day, so the same nudge does not arrive word for
  /// word every evening.
  static String _pick(List<String> lines, DateTime? day) =>
      lines[_daysSinceEpoch(day ?? DateTime.now()) % lines.length];

  /// The evening nudge while the 21-day challenge is running. Names the day,
  /// because the number is the reason to keep going.
  static String challengeTitle(int day, int length) => day >= length
      ? 'Last day. Finish the path 🏁'
      : 'Day $day of your challenge';

  static String challengeBody({
    required int pending,
    required String firstPending,
  }) => pending == 1
      ? '$firstPending is all that is left. Keep your path going.'
      : '$pending habits left to keep your path going.';

  static const String catchUpTitleLabel = 'Daily catch-up';
  static const String catchUpBlurb =
      'One nudge in the evening if the day is not logged. It mentions your '
      'streak when there is one to lose — a broken streak and an unlogged day '
      'are the same thing, so it never sends twice.';

  static const String habitRemindersTitle = 'Reminders';
  static const String habitRemindersBlurb =
      'Nudges just for this habit, at times you choose.';

  /// The whole of the card when reminders are switched off. It used to be a
  /// sentence pointing at a switch on another screen; this is the switch.
  static const String habitRemindersOff = 'Turn reminders on';

  static const String habitRemindersEmpty =
      'None yet. Add one and pick the wording.';

  /// The two sections the notifications screen is split into. Named for the
  /// screen rather than for the habit detail page, which has its own pair of
  /// reminder strings above.
  static const String sectionHabitTitle = 'For your habits';
  static const String sectionHabitBlurb =
      'Tied to one habit. They stop when that habit does.';

  static const String generalTitle = 'General reminders';
  static const String generalLine = 'Your own, at times you pick.';

  static const String kindHabitTitle = 'Habit reminders';
  static const String kindHabitEmpty = 'Add one from any habit.';
  static const String goToHabits = 'Go to habits';
  static const String catchUpLine = "If today isn't done by evening.";
  static const String catchUpAt = 'At';

  // -- the evening nudge, as the settings screen shows it --------------------

  static const String sectionDaily = 'Every evening';
  static const String sectionReminders = 'Reminders';
  static const String sectionMore = 'More';
  static const String challengeToggleTitle = '21-day challenge';
  static const String challengeToggleLine = 'Your challenge day, same nudge.';
  static const String challengeNotStarted = 'Starts with your challenge.';
  static const String nudgeTime = 'Time';
  static const String oneADay = 'Never more than one a day.';
  static const String habitRemindersLine = 'Set on each habit.';
  static const String masterOffLine = 'Turn on for gentle nudges.';
  static const String masterOnLine = "You're all set.";
  static const String generalBlurb =
      'Not tied to anything — they arrive whatever is on your list.';

  // -- action buttons -------------------------------------------------------

  // -- settings screen ------------------------------------------------------

  static const String screenTitle = 'Notifications';
  static const String screenSubtitle = 'Yours to set up, however you like.';

  static const String masterTitle = 'Notifications';
  static const String masterBlurb =
      'You choose what each one says, when it arrives, and how many there are.';

  static const String emptyTitle = 'No reminders yet';
  static const String emptyBody =
      'Add one and pick the wording, or write your own.';

  static const String addLabel = 'Add reminder';
  static const String presetsTitle = 'Pick a style';
  static const String customLabel = 'Write my own';

  static const String editorNewTitle = 'New reminder';
  static const String editorEditTitle = 'Edit reminder';
  static const String editorTextLabel = 'What it says';
  static const String editorTextHint = 'Time for a walk';
  static const String editorTimeLabel = 'Time';
  static const String editorDaysLabel = 'Repeat';
  static const String editorPreviewLabel = 'Preview';

  /// Stated on the reminder sheet rather than offered as a choice.
  static const String quietWhenDone =
      'Stays quiet once this is logged for the day.';

  static const String withQuoteTitle = "Add today's quote";
  static const String withQuoteBlurb = 'One line a day, under every reminder.';

  static const String skipWhenHabitDoneTitle = 'Skip once this one is ticked';
  static const String skipWhenHabitDoneBlurb =
      'Stays quiet as soon as you log this habit for the day.';

  static const String skipWhenDoneTitle = 'Skip if the day is done';
  static const String skipWhenDoneBlurb =
      'Stays quiet when every habit is already logged.';

  static const String permissionDenied =
      'Notifications are off in phone settings.';

  /// Shown when the app's own switch and Android's own switch disagree.
  ///
  /// The app cannot turn this one back on for you — nothing an app does can
  /// grant itself a permission — so the only useful thing to say is where the
  /// control actually is.
  static const String systemBlocked =
      'Blocked in phone settings. Turn on in Settings › Apps › RewireMind.';

  static const String batteryWarning =
      'Some phones stop background apps from posting reminders. If they stop '
      'arriving, allow RewireMind to run in the background in system settings.';

  static int _daysSinceEpoch(DateTime day) =>
      DateTime(day.year, day.month, day.day).difference(DateTime(2020)).inDays;
}
