import 'package:intl/intl.dart';

import '../models/day_phase.dart';
import '../models/progress_range.dart';
import 'premium_content.dart';
import '../models/premium.dart';

/// ============================================================================
/// APP COPY
/// ============================================================================
/// Every user-facing string that isn't derived from data lives here — quotes,
/// handwritten annotations, section headings, encouragement banners.
///
/// Swap or localise the app by editing this one file; no widget hardcodes copy.
/// ============================================================================

class AppContent {
  const AppContent._();

  static const String appName = 'RewireMind';
  static const String tagline = 'Small steps. A better you.';

  // -- Home -----------------------------------------------------------------

  /// Greeting prefix chosen by time of day.
  static String greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Emoji paired with the greeting.
  static String greetingEmoji(DateTime now) {
    final h = now.hour;
    if (h < 12) return '☀️';
    if (h < 17) return '🌤️';
    return '🌙';
  }

  /// The quote under the Home greeting, in three pools.
  ///
  /// One pool read the same at six in the morning and ten at night, which is
  /// how a line meant to land ends up as furniture. "Start before you feel
  /// ready" is a morning sentence; at bedtime the honest one is "a quiet win
  /// still counts". The header gives this about two lines at a glance, so
  /// every one of them is a phrase rather than a paragraph — see the test that
  /// holds them to it.

  /// 5am to 10am.
  static const List<String> homeQuotesMorning = [
    'Win the morning, win the day.',
    'First hour, best hour.',
    'Start before you feel ready.',
    'Small steps become a whole life.',
    'The day is blank. Fill it well.',
    'Wake up. Show up. Repeat.',
  ];

  /// 10am to 7pm.
  static const List<String> homeQuotesDay = [
    'One percent better, every day.',
    'Consistency beats intensity.',
    'Do it badly. Just do it daily.',
    'You are what you repeat.',
    'Momentum loves a small start.',
    'Discipline is a kind of freedom.',
  ];

  /// 7pm to 5am.
  static const List<String> homeQuotesNight = [
    'Finish what the morning started.',
    'A quiet win still counts.',
    'Tomorrow is built tonight.',
    'Rest is part of the work.',
    'One more, then sleep.',
    'Close the day on your terms.',
  ];

  /// The pool for a time of day.
  static List<String> homeQuotesFor(DayPhase phase) => switch (phase) {
    DayPhase.earlyMorning => homeQuotesMorning,
    DayPhase.day => homeQuotesDay,
    DayPhase.night => homeQuotesNight,
  };

  /// Everything the app has to say, for the profile quote picker.
  ///
  /// The three pools plus a handful that are about the person rather than the
  /// hour — a profile quote is a thing you keep, not a thing that rotates.
  static const List<String> profileQuoteLibrary = [
    'Progress, not perfection.',
    'Better habits, brighter days.',
    'Doing it anyway.',
    'Still here. Still going.',
    'Quietly getting on with it.',
    'One day at a time.',
    'Built, not born.',
    'Boring consistency, remarkable results.',
    'I keep my promises to myself.',
    'Future me says thanks.',
    ...homeQuotesMorning,
    ...homeQuotesDay,
    ...homeQuotesNight,
  ];

  /// What the brain on Home says about *your* day, in its speech bubble.
  ///
  /// Four words or so: the bubble sits between the quote and the tree. Only
  /// true things — a count of what is left, a streak worth naming, a day
  /// that is finished.
  static List<String> heroAboutYou({
    required int done,
    required int total,
    required int streak,
    required bool hasHabits,
  }) {
    if (!hasHabits) return const ['Add a habit?', 'Start with one.'];
    if (total == 0) return const ['Free day today!'];
    final left = total - done;
    return [
      if (left == 0) ...['All done! 🎉', 'Day closed. Nice!'],
      if (left > 0 && done == 0)
        left == 1 ? '1 to go today!' : '$left to go today!',
      if (left > 0 && done > 0) '$done down, $left to go!',
      if (left == 1) 'Just one left!',
      if (streak >= 2) '$streak-day streak! 🔥',
    ];
  }

  static const String homeScript = 'Progress\ntoday\nfor a brighter\ntomorrow';

  /// Just "Habits". The line above it already says the date, and the row
  /// carries a count and a view switch as well — "Today's Habits" on top of
  /// "Today, 9 Sep" was the same word twice on consecutive lines.
  static const String homeTodaySection = 'Habits';

  static const String emptyDayTitle = 'Your first habit';
  static const String emptyDayBody = 'Start small. Tap + to begin.';

  /// Habits, but none of them on today.
  static const String freeDayTitle = 'A free day';
  static const String freeDayBody = 'Nothing scheduled today.';

  /// The same day, looked back at: nothing was on for it.
  static const String freeDayPastBody = 'Nothing was scheduled that day.';

  /// The handwritten nudge beside the arrow to +, on an empty Home.
  static const String plusHint = 'Start here';

  /// Home, while habits are being put in order.
  static const String arrangeHint = 'Drag to reorder';
  static const String arrangeDone = 'Done';

  static const String overviewEmptyTitle = 'Your week at a glance';
  static const String overviewEmptyBody = 'Add a habit to fill it in.';
  static const String breakdownEmptyTitle = 'Habit by habit';
  static const String breakdownEmptyBody = "Each habit's rate lands here.";
  static const String homeViewCalendar = 'View Calendar';
  static const String homeEncouragementTitle = 'Keep going!';
  static const String homeEncouragementBody = "You're improving";

  /// What a finished habit says when there is no count to quote — a habit
  /// you either did or did not. Anything with a target quotes the target
  /// instead: "10 / 10 pages" is the fact, and the tick beside it is the
  /// celebration. It used to read "Completed! 🎉" on every row of a finished
  /// day, which is eight exclamation marks and eight party poppers.
  static const String habitDone = 'Done';

  /// Shown under the list on a day where everything is logged.
  static const String homeDayClosed = 'Day closed ❤️';
  static const String homeStreakLabel = 'day streak';

  /// The celebration's look-ahead, which gets two lines and room to
  /// breathe rather than a whisper at the bottom of the screen.
  static const String tomorrowLabel = 'Tomorrow';
  static String tomorrowCount(int count) => switch (count) {
    0 => 'Nothing scheduled — enjoy it',
    1 => '1 habit waiting',
    _ => '$count habits waiting',
  };

  /// "Tomorrow · 5 habits", or nothing to do at all.
  static String homeTomorrow(int count) => switch (count) {
    0 => 'Nothing scheduled tomorrow',
    1 => 'Tomorrow · 1 habit',
    _ => 'Tomorrow · $count habits',
  };

  static const String detailNotesAdd = 'Add note';
  static const String detailNotesEmpty = 'Nothing written yet.';

  // -- The 21-day path ------------------------------------------------------

  /// The once-a-day arrival, when the trail has just climbed a stop.
  ///
  /// Names the number, because the number is the reward: "Day 6" after six
  /// days of not missing is a different sentence from "well done".
  static String pathArrivedTitle(int stop, int total) => 'Day $stop of $total.';

  static String pathArrivedBody(int left) => switch (left) {
    0 => 'That is the whole path. It is a habit now.',
    1 => 'One more day.',
    _ => '$left days to go.',
  };

  static const String pathArrivedButton = 'Back to Home';

  static const String pathTitle = '21-Day Path';
  static const String musicOff = 'Music off';
  static const String musicOn = 'Music on';
  // -- your data ------------------------------------------------------------

  static const String dataTitle = 'Export and import data';

  static const String dataIntroTitle = 'A copy you own';
  static List<String> dataIntroPoints(int habits, int checkIns) => [
    'A lost phone is a lost history — there is no copy anywhere else.',
    'Right now: $habits ${habits == 1 ? 'habit' : 'habits'}, '
        '$checkIns ${checkIns == 1 ? 'check-in' : 'check-ins'}.',
  ];

  static const String dataExportTitle = 'Export your data';
  static const String dataExportBody =
      'Every day since you started, every habit and note, as Excel or PDF.';
  static const String dataExportSubject = 'My RewireMind history';

  static const String dataFormatTitle = 'Export as';
  static const String dataFormatBody =
      'Both include every day since you started, every habit and every note.';
  static const String dataFormatExcel = 'Excel spreadsheet';
  static const String dataFormatExcelBody =
      'A sheet for each: summary, habits, daily log, calendar and notes.';
  static const String dataFormatPdf = 'PDF report';
  static const String dataFormatPdfBody =
      'Your photo and numbers, then a calendar for every month, then notes.';

  static const String dataCopyTitle = 'Copy to clipboard';
  static const String dataCopyBody =
      'The same data as text, for pasting straight into a note.';
  static String dataCopied(int kb) => 'Copied — $kb KB of JSON';

  /// Temporary review aid: fills the app with a generated history so the
  /// board, the charts and the challenge can all be looked at without three
  /// months of waiting. Remove the row, the asset and the flag together.
  static const String dataRehearseTitle = 'Stand on day 2';
  static const String dataRehearseBody =
      'Back-dates the challenge one day so the path walks itself next launch.';
  static const String dataRehearseDone =
      'Done. Close the app and open it again to watch the path.';
  static const String dataRehearseNeedsDay =
      'Finish today first — the path only walks after a day you kept.';

  static const String dataDemoTitle = 'Load demo data';
  static const String dataDemoBody =
      'Eight habits and seventy-five days of history. Replaces what is here.';
  static String dataDemoDone(int habits, int checkIns) =>
      'Loaded $habits habits and $checkIns check-ins';

  static const String dataImportTitle = 'Import from Excel';
  static const String dataImportBody =
      'Bring back everything from an Excel file you exported: habits, '
      'history, streaks, notes and the challenge.';
  static const String dataImportAction = 'Import';
  static const String dataImportUnreadable =
      'That file has no RewireMind data in it — nothing was changed. Use an '
      'Excel file exported from this screen.';
  static String dataImported(int habits) =>
      'Restored $habits ${habits == 1 ? 'habit' : 'habits'}';

  /// Says what is coming in and what it lands on top of, because restoring
  /// replaces rather than merges.
  static String dataImportConfirm({
    required int habits,
    required int checkIns,
    DateTime? takenAt,
    String? name,
  }) {
    final when = takenAt == null
        ? 'This backup'
        : 'This backup from ${DateFormat('d MMM yyyy').format(takenAt)}';
    final whose = name == null ? '' : ", $name's,";
    return '$when$whose holds $habits '
        '${habits == 1 ? 'habit' : 'habits'} and $checkIns '
        '${checkIns == 1 ? 'check-in' : 'check-ins'}. Importing replaces '
        'everything on this phone with it. What is here now is not kept.';
  }

  // -- about ----------------------------------------------------------------

  static const String aboutTitle = 'About';
  static const String aboutWebsite = 'Website';
  static const String aboutX = 'Follow us on X';
  static const String aboutLinkedIn = 'Follow us on LinkedIn';
  static const String aboutRate = 'Rate the app';
  static const String aboutRateBody = 'A minute of your time, and it helps.';
  static const String aboutTerms = 'Terms of Service';
  static const String aboutPrivacy = 'Privacy Policy';

  static const String linkFailed = 'Nothing on this phone can open that link.';

  // -- help -----------------------------------------------------------------

  static const String helpTitle = 'Help & Feedback';

  static const String helpTutorial = 'How it works';
  static const String helpTutorialBody =
      'A short walk through the app, any time you want it.';
  static const String helpNoMail =
      'No mail app is set up on this phone. Write to ';

  // -- the board ------------------------------------------------------------

  /// "Board", not "The board": it sits where a section heading goes, beside
  /// "Habits", and headings in this app are nouns rather than sentences.
  static const String boardTitle = 'Board';
  static const String boardNamesHeader = 'HABITS';
  static const String boardEmptyTitle = 'Your board';
  static const String boardEmptyBody = 'Every day you log paints a tile.';

  /// Says what the intensity means. Without it the board is pretty and
  /// ambiguous — a pale cell could be a light day or a light colour.
  static const String boardLegend = 'Deeper colour, more of it done';

  /// Shown under the board's legend swatch, at the ends of the ramp.
  // -- Sharing the board ----------------------------------------------------

  static const String shareTitle = 'Share your board';
  static const String shareBlurb =
      'Send it to anyone, or save it to your photos.';
  static const String shareAction = 'Share';

  /// "Ada's habits" — first name only, because this goes to people who know
  /// them by it.
  static String shareCardTitle(String first) => "$first's habits";
  static const String shareCardTitleAnon = 'My habits';

  /// "8 habits · the last 70 days"
  static String shareCardSubtitle(int habits, int days) =>
      '$habits habits · the last $days days';
  static const String shareCardFooter = 'RewireMind · rewired.app';

  /// Sent alongside the picture of the board.
  static const String shareMessage =
      'Ten weeks of my habits, one colour each. Made with RewireMind — '
      'rewiremind.app';
  static const String shareFailed = 'Could not make the picture. Try again?';

  static const String boardLegendLow = 'a little';
  static const String boardLegendHigh = 'all of it';

  /// The view switch names the view it goes to, not the one you are in —
  /// the way every list/grid button in every app does.
  static const String boardSwitchToBoard = 'Board';
  static const String boardSwitchToList = 'List';

  /// Shown over the clock when a reminder is being set up from scratch.
  static const String reminderPickTime = 'When should it arrive?';

  // -- Adding a habit while looking at another day --------------------------

  /// "Start it on Tue 8 Sep?"
  static String backdateTitle(String day) => 'Start it on $day?';

  static String backdateBody(String day) =>
      'You are looking at $day, not today. Starting the habit there counts '
      'every day since — including any you have already missed — towards its '
      'streak and its completion rate.';

  static String backdateStartThen(String day) => 'Start $day';
  static const String backdateStartToday = 'Start today';

  // -- One day, in full -----------------------------------------------------

  /// "3 missed" — the part of a day the count above it does not say.
  static String dayMissed(int n) => '$n missed';

  // -- Home stat strip ------------------------------------------------------
  //
  // Each label carries its own window, because the strip mixes them: a run
  // that goes back as far as it goes back, and a count inside this week.

  static const String statStreak = 'day streak';
  static const String statPerfectThisWeek = 'perfect this week';

  // -- habit colours --------------------------------------------------------

  /// The board's palette, as a ramp rather than a set.
  ///
  /// Habits take these in order, so the board comes out as one warm gradient
  /// from top to bottom instead of a scatter of unrelated hues. That is what
  /// makes it read as a single picture of a week: neighbouring rows belong to
  /// each other, and a row that is doing badly shows up as a pale gap in an
  /// otherwise solid field.
  ///
  /// Yellow through to magenta, all fully saturated, because the board's other
  /// axis — how much of a habit was done — is carried by lightness. A muddy
  /// swatch in here would read as a bad day rather than as a colour.
  static const List<int> habitColours = [
    0xFFF5C518, // yellow
    0xFFF59E0B, // amber
    0xFFF97316, // orange
    0xFFEA580C, // deep orange
    0xFFEF4444, // red
    0xFFDC2626, // crimson
    0xFF991B1B, // dark red
    0xFFFB7185, // salmon
    0xFFC026D3, // violet
    0xFFDB2777, // magenta
  ];

  static const String colourLabel = 'Colour';

  // -- how it works ---------------------------------------------------------

  // -- account --------------------------------------------------------------

  // -- Account, Help and About: the grouped screens -------------------------
  //
  // Section headings, so the rows underneath them do not have to explain what
  // kind of thing they are. All three screens used to be a stack of separate
  // cards with no grouping at all, which is why every row looked equally
  // important and none of them looked related.

  static const String groupProfile = 'Profile';
  static const String groupYourData = 'Your data';
  static const String groupThisPhone = 'Storage';
  static const String groupDanger = 'Danger zone';

  static const String accountEdit = 'Name and photo';
  static const String accountEditBody = 'How the app greets you';
  static const String accountRestore = 'Restore a backup';
  static const String accountRestoreBody = 'Replace everything with a file';

  /// "Tracking since 27 Jun 2026" as a row value rather than a sentence.
  static const String accountStarted = 'Started';

  static const String groupStart = 'Getting started';
  static const String groupQuestions = 'Common questions';
  static const String groupReach = 'Get in touch';
  static const String groupFollow = 'Follow';
  static const String groupLegal = 'Legal';

  static const String helpTour = 'Show me around';
  static const String helpTourBody = 'The quick tour of Home, again';
  static const String helpProblem = 'Report a problem';
  static const String helpProblemBody = 'Something is wrong or missing';

  /// The questions people actually arrive with, and true answers to them.
  ///
  /// Written against how the app really behaves rather than how it ought to:
  /// the completion rate genuinely does count only finished days, and saying
  /// so here is cheaper than somebody deciding the numbers are broken.
  static const List<(String, String)> helpFaq = [
    (
      'Does a half-finished day count?',
      'Not towards a completion rate — those count a habit on the days it '
          'reached its target. The board shades part-days by how much you '
          'did, so six pages out of ten still shows up there; it just is not '
          'counted as done.',
    ),
    (
      'What breaks a streak?',
      'A day where something you scheduled was not completed. Days a habit '
          'is not scheduled for do not count against it, so a weekday-only '
          'habit is safe at the weekend.',
    ),
    (
      'Why did my 21-day path go back to one?',
      'It asks for twenty-one days in a row. Miss one and it restarts — '
          'continuous is the whole idea, and a path that paused for you would '
          'not be measuring anything.',
    ),
    (
      'Can I fill in a day I missed?',
      'Yes. Open the habit — from its row, from a block on the board, or from '
          'a day in the calendar — and use the card at the top. The grids '
          'themselves only show; they never change a day, so you cannot lose '
          'a part-done one by mistake.',
    ),
    (
      'My reminders are not arriving.',
      'Check the master switch under Notifications first. If it is on, the '
          'usual culprit is the phone: many Android builds stop background '
          'apps to save battery, and RewireMind has to be allowed to run in '
          'the background for a reminder to be posted on time.',
    ),
    (
      'Where is my data kept?',
      'On this phone, and nowhere else. There is no account and no server, '
          'which also means nothing is backed up for you — export a copy from '
          'Account before you change phones.',
    ),
  ];

  static const String aboutLicences = 'Open-source licences';
  static const String aboutLicencesBody = 'What RewireMind is built on';
  static const String aboutVersion = 'Version';
  static const String aboutMadeBy = 'Made for people who keep starting over.';

  static const String accountTitle = 'Account';

  static const String accountLocalTitle = 'This phone, and nowhere else';

  /// The bullet list this replaced said the same three things in three lines.
  static const String accountLocalBody =
      'No account, no server, nothing uploaded';
  static const List<String> accountLocalPoints = [
    'No account. No sign-in.',
    'Everything is stored on this device only.',
    'Nothing is uploaded. Nobody else can read it.',
  ];

  static const String accountDataTitle = 'What is stored';
  static const String accountSince = 'Tracking since';
  static const String accountHabits = 'Habits';
  static const String accountCheckIns = 'Check-ins';
  static const String accountNotes = 'Notes';

  static const String accountExportTitle = 'Copy my data';
  static const String accountExportBody =
      'Everything as JSON, onto the clipboard.';
  static String accountExported(int kb) => 'Copied — $kb KB of JSON';

  static const String accountDeleteTitle = 'Delete my account';
  static const String accountDeleteBody =
      'Your name, your photo, and every habit, check-in and note';
  static const String accountDeleteConfirm =
      'This removes the account and everything in it from this phone. There '
      'is no copy anywhere else, so this cannot be undone — export a backup '
      'first if you might want it back.';
  static const String accountDeleted = 'Account deleted';

  // -- Start over -----------------------------------------------------------
  //
  // Different from deleting the account: the person stays, the record goes.

  static const String resetTitle = 'Start over?';
  static const String resetBody =
      'Every habit, check-in and note is cleared and the 21-day challenge '
      'goes back to not started. Your name and photo stay as they are.';
  static const String resetConfirm = 'Clear it all';
  static const String resetDone = 'Cleared — a clean page';

  // -- home screen widget ---------------------------------------------------

  // -- the 21-day challenge -------------------------------------------------

  static const String rulesTitle = 'The 21-day challenge';

  static const String rulesHeadline = 'Rewire your brain in 21 days';

  /// The promise, in three lines. It was a paragraph, and a paragraph on the
  /// way in to a commitment is a paragraph nobody reads.
  static const List<String> rulesPromise = [
    'Twenty-one days in a row and it stops being a decision.',
    'The pathway wears in — your brain reaches for it on its own.',
    'After that you do not need an app to remind you.',
  ];

  /// In the order they apply, which is why they are numbered.
  static const List<String> rules = [
    'All your habits done in a day = one day earned.',
    'Partway counts on a habit. A day needs all of them.',
    'Twenty-one days in a row finishes the challenge.',
    'Medals at day 7, 14 and 21 — bronze, silver, gold.',
    'Days ahead stay grey. Hold one for a peek.',
  ];

  static const String rulesHardTitle = 'Miss a day, start again';

  /// Short lines, because this is the one thing on the screen that has to
  /// land. A paragraph explaining a penalty reads as an excuse for it.
  static const List<String> rulesHard = [
    'Miss a day and it starts again at day 1.',
    'Past challenge days are locked — changing one restarts it.',
    'Today stays open until midnight.',
    'Your habits and history are never touched.',
  ];

  /// Asked before a change to a challenge day that is already over.
  /// What the faint cells before a habit's first day are.
  static String trackedFrom(String habit, String day) =>
      '$habit has been tracked since $day.';

  // -- a day the habit was not being tracked on -----------------------------

  /// Backdating: a habit added today, and the last few days filled in.
  static String trackEarlierTitle(String day) => 'Track $day too?';
  static String trackEarlierBody(String habit) =>
      '$habit was not running that day, so nothing you put there would count. '
      'Start it from then and it joins your streaks and charts.';
  static const String trackEarlierNo = 'Not now';
  static const String trackEarlierYes = 'Start from then';
  static String trackEarlierDone(String habit, String day) =>
      '$habit now starts on $day.';

  /// The two that are not offered, and why.
  static String trackOffSchedule(String habit, String weekday) =>
      '$habit does not run on ${weekday}s. Change its days to track this one.';
  static String trackClosed(String habit, String day) =>
      '$habit was discontinued on $day.';

  static const String challengeLockTitle = "You're on the 21-day challenge";
  static const String challengeLockBody =
      'Past days of the challenge are locked. Changing this one restarts the '
      'challenge from day 1, today.';
  static const String challengeLockKeep = 'Keep it';
  static const String challengeLockGo = 'Change & restart';
  static const String challengeRestarted =
      'Challenge restarted. Today is day 1.';

  static const String rulesBegin = 'I understand — show me the path';
  static const String rulesBack = 'Back to the path';

  // -- profile photograph ---------------------------------------------------

  static const String profilePhotoHint = 'Tap to change your photo';

  static const String cropTitle = 'Frame your photo';
  static const String cropHint = 'Drag to move, pinch to zoom.';
  static const String cropSave = 'Use this';

  static const String photoFromGallery = 'Choose a photo';
  static const String photoFromCamera = 'Take a photo';
  static const String photoRemove = 'Remove photo';
  static const String photoFailed =
      'That photo could not be used. Try another one.';

  static const String widgetsTitle = 'Widgets';

  static const String widgetTitle = 'Pick your widget';

  static String widgetViewName(String view) => switch (view) {
    'mascot' => 'Mascot',
    'list' => 'Checklist',
    'week' => 'Week',
    _ => 'Month',
  };

  /// One line under the picker. Short: the preview above it does the telling.
  static String widgetViewLine(String view) => switch (view) {
    'mascot' => 'A brain that lives your day, hour by hour.',
    'list' => "Today's habits. Done ones get struck out.",
    'week' => 'Your week, day by day.',
    _ => 'The whole month at a glance.',
  };

  static String widgetSizeName(String size) => switch (size) {
    'strip' => 'Strip',
    'small' => 'Square',
    'medium' => 'Wide',
    _ => 'Size',
  };

  static const String widgetAdd = 'Add to home screen';
  static const String widgetHint =
      'Or long-press your home screen and pick Widgets.';

  static const String widgetSkip = 'Not now';

  /// Said the moment Android confirms a widget is on the home screen.
  static String widgetAdded(String kind) => switch (kind) {
    'list' => "Added! Today's checklist is on your home screen ✅",
    'week' => 'Added! Your week is on your home screen 📅',
    'month' => 'Added! Your month is on your home screen 🗓️',
    _ => 'Added! Your brain now lives on your home screen 🧠',
  };

  static const String widgetManual =
      'Long-press an empty spot on your home screen, choose Widgets, and find '
      'RewireMind.';

  // -- appearance -----------------------------------------------------------

  static const String appearanceTitle = 'Appearance';

  static const String manualPhaseTitle = 'Set the time of day myself';
  static const String manualPhaseOff =
      'Follows the clock: light morning, bright day, dark night.';
  static const String manualPhaseOn = 'Pick the look you want to keep.';

  /// The hours a phase covers, so the choice says what it means.
  static String phaseHours(DayPhase phase) => switch (phase) {
    DayPhase.earlyMorning => '5:00 am to 9:59 am',
    DayPhase.day => '10:00 am to 6:59 pm',
    DayPhase.night => '7:00 pm to 4:59 am',
  };

  static const String pathTagline = 'Take 21 steps to make it a habit';

  /// One line per character, revealed only when you reach that day — so
  /// arriving somewhere gives you both the movement and the words, and
  /// nothing tells you the middle of week two is dull before you get there.
  static String pathLine(int day) => switch (day) {
    4 => 'Still takes thinking',
    7 => 'One week down',
    11 => 'Making it look easy',
    14 => 'Getting easier',
    18 => 'Barely a decision',
    _ => "It's yours now",
  };

  /// The character waiting at the foot of the path.
  static const String pathStart = 'Start here';
  static const String pathFinished = 'Twenty-one days. It is wired in now.';

  /// "of 21 days kept" — sits beside the count, so it never repeats it.
  static String pathOf(int total) => 'of $total days kept';

  static String pathNextMilestone(int away) => away == 1
      ? 'One more day to the next milestone'
      : '$away days to the next milestone';

  /// The three weeks, and what each one is for.
  static String weekLabel(int week) => 'Week $week';
  static String weekName(int week) => switch (week) {
    1 => 'Repetition',
    2 => 'Rhythm',
    _ => 'Routine',
  };

  static const String challengeCardTitle = 'Rewire your brain in 21 days';

  static const String pathStripTitle = 'Rewire your brain';

  /// The count over the character's head on Home. Terse on purpose: it has
  /// about seventy pixels between the quote and the tree.
  static String pathBadge(int done, int total) => '$done/$total';

  /// "Day 9 of 21" — the short form, for places with a pill's worth of room.
  /// The long one carries the challenge's name as well and runs to thirty-odd
  /// characters, which overflowed the celebration's badge off the screen.
  static String pathDayOf(int done, int total) => 'Day $done of $total';

  static String pathStrip(int done, int total) =>
      'The 21-day challenge · day $done of $total';
  static const String pathStripHint = 'Your 21-day path';

  /// The card before anybody has joined. It is an offer at this point, and
  /// saying "day 0 of 21" about a challenge nobody started reads as a failure
  /// rather than an invitation.
  static const String challengeGiveUpTitle = 'Give up the challenge?';
  static const String challengeGiveUpBody =
      'It stops counting and comes off your home screen. Everything you have '
      'logged stays exactly as it is — those days happened either way. You '
      'can start again whenever you like, from day one.';
  static const String challengeGiveUpConfirm = 'Give up';
  static const String challengeKeepGoing = 'Keep going';

  static const String challengeNotStarted = 'Not started · tap to begin';

  /// The badge that marks it as running, on the card and on Home.
  static const String challengeLive = 'LIVE';

  /// The badge on Home while the challenge is running.
  static String challengeBadge(int done, int total) => 'Day $done of $total';

  // -- Calendar -------------------------------------------------------------

  static const String calendarTitle = 'Calendar';
  static const String calendarSubtitle = 'Your journey, one day at a time.';
  static const String calendarScript = 'Consistency\ncreates\nchange';
  static const String calendarLegendAll = 'All habits done';
  static const String calendarLegendSome = 'Some done';
  static const String calendarLegendNone = 'None done';
  static const String calendarLegendToday = 'Today';
  static const String calendarOverviewTitle = 'Habit Overview';
  static const String calendarStreakLabel = 'Streak';
  static const String calendarHabitColumn = 'Habit';
  static const String calendarBannerTitle = "You're building a better you!";
  static const String calendarBannerScript = 'Keep\ngoing 💚';

  /// "4 of 7 habits completed this week."
  static String calendarBannerBody(int done, int total) =>
      '$done of $total habits completed this week.';

  // -- Progress -------------------------------------------------------------

  static const String progressTitle = 'Progress';
  static const String progressRangeTooltip = 'Change period';

  static const Map<ProgressRange, ProgressCopy> progress = {
    ProgressRange.week: ProgressCopy(
      subtitle: "Track your consistency and see how far you've come.",
      script: 'Progress\ntoday,\na better\ntomorrow.',
      chartTitle: 'Daily Completion',
      chartSubtitle: 'Percentage of your scheduled habits completed each day',
      breakdownSubtitle: 'Completion rate for each habit this week',
      comparisonLabel: 'vs. Last Week',
      bannerTitle: 'Great progress this week!',
      bannerVerb: 'You completed',
      bannerTail: 'Keep going, consistency creates change.',
    ),
    ProgressRange.month: ProgressCopy(
      subtitle: 'Your month at a glance.',
      script: 'Progress\nbuilds\nhappier\ndays.',
      chartTitle: 'Weekly Completion',
      chartSubtitle: 'Percentage of your scheduled habits completed each week',
      breakdownSubtitle: 'Completion rate for each habit this month',
      comparisonLabel: 'vs. Last Month',
      bannerTitle: 'Great progress this month!',
      bannerVerb: 'You completed',
      bannerTail: 'Consistency creates change.',
    ),
    ProgressRange.year: ProgressCopy(
      subtitle: 'A year of progress, one step at a time.',
      script: 'Consistent\ntoday.\nStronger\ntomorrow.',
      chartTitle: 'Monthly Completion',
      chartSubtitle: 'Percentage of your scheduled habits completed each month',
      breakdownSubtitle: 'Completion rate for each habit this year',
      comparisonLabel: 'vs. Last Year',
      bannerTitle: "You're building a great year!",
      bannerVerb: "You've completed",
      bannerTail: 'Small steps make a big difference.',
    ),
    ProgressRange.allTime: ProgressCopy(
      subtitle: 'Your journey. Your growth.',
      script: 'A healthier,\nhappier you\n— always.',
      chartTitle: 'Yearly Completion',
      chartSubtitle: 'Your completion rate over time',
      breakdownSubtitle: 'Overall completion rate for each habit',
      comparisonLabel: 'Days Active',
      bannerTitle: 'Look how far you\'ve come!',
      bannerVerb: "You've completed",
      bannerTail: "Here's to many more good days ahead.",
    ),
  };

  /// The Progress banner's headline and line, honest about the numbers.
  ///
  /// "Great progress" is earned, not printed: with nothing logged it said the
  /// same thing as with everything logged, which is how a compliment turns
  /// into wallpaper.
  ///
  /// The line is null where the screen should show the counts, which it
  /// formats itself.
  static ({String title, String? line, String script}) progressBanner(
    ProgressRange range, {
    required int completed,
    required int scheduled,
    required int percent,
  }) {
    if (scheduled == 0) {
      return (
        title: 'Nothing to count yet',
        line: 'Add a habit to start the chart.',
        script: 'Start\nsmall 🌱',
      );
    }
    if (completed == 0) {
      return (
        title: 'A fresh start',
        line: 'Tick one habit to get going.',
        script: 'Start\nsmall 🌱',
      );
    }
    final title = percent >= 75
        ? progressFor(range).bannerTitle
        : percent >= 40
        ? 'Good momentum'
        : 'Every tick counts';
    return (title: title, line: null, script: calendarBannerScript);
  }

  static ProgressCopy progressFor(ProgressRange range) =>
      progress[range] ?? progress[ProgressRange.week]!;

  static const String chartEmptyTitle = 'Your progress, charted';
  static const String chartEmptyBody = 'Tick a habit and it starts to grow.';

  // Progress stat-tile labels
  static const String statCompletionRate = 'Completion Rate';
  static const String statDayStreak = 'Day Streak';
  static const String statBestStreak = 'Best Streak';
  static const String statActiveHabits = 'Active Habits';
  static const String statTotalHabits = 'Total Habits';
  static const String statDaysActive = 'Days Active';
  static const String statThisWeek = 'This Week';
  static const String statPerfectDays = 'Perfect Days';

  /// A day where every scheduled habit was completed.
  static const String perfectShort = 'perfect';
  static const String statThisMonth = 'This Month';
  static const String progressBreakdownTitle = 'Habit Breakdown';
  static const String progressCompletedColumn = 'Completed';
  static const String progressRateColumn = 'Rate';
  static const String keepGoing = 'Keep going!';

  // Stat-tile notes are deliberately terse: the tiles sit four-across, and a
  // sentence in each one made the row twice as tall as it needed to be.

  /// Only shown when there is no streak to describe. A run of five days does
  /// not need "days in a row" written under it — the label already says Day
  /// Streak, and the tiles sit four across.
  static const String streakNone = 'start one today';

  /// "22 check-ins" — the scale behind the percentage, with its unit, since
  /// a bare ratio under a percentage gets read as a count of days.
  static String checkInCount(int done) => done == 1
      ? '1 check-in'
      : '${NumberFormat.decimalPattern().format(done)} check-ins';

  static const String nowTracking = 'in your list';
  static const String everTracked = 'ever created';

  /// Shown in place of a comparison during the first period, when there is no
  /// previous one to compare against.
  static const String comparisonNone = 'nothing to compare yet';

  /// "58% → 64%"
  static String comparisonBlurb(int previous, int current) =>
      '$previous% → $current%';

  // -- Profile --------------------------------------------------------------

  static const String profileTitle = 'Profile';
  static const String profileScript = 'Better\nhabits\nbrighter\ndays';
  static const String profileEditButton = 'Edit profile';
  static const String profileEditTitle = 'Edit profile';
  static const String profileSaveButton = 'Save';
  static const String profileNameLabel = 'Name';
  static const String profileNameRequired = 'Your name cannot be empty';
  static const String profileQuoteLabel = 'Your quote';
  static const String profileQuotePick = 'Pick one instead';
  static const String profileQuoteSheet = 'Choose a quote';
  static const String profileQuoteHint = 'Progress, not perfection.';
  static const String profileLogOut = 'Log Out';

  /// Rows in the Profile settings list. Functionality lands later; the
  /// `id` is what each row's future screen will key off.
  /// The line beside the checkbox on the rules screen.
  static const String rulesAgree =
      'I have read the rules and I am starting today.';

  // -- Signing in -----------------------------------------------------------

  static const String signOutTitle = 'Sign out?';
  static const String signOutBody =
      'Your habits, check-ins and notes all stay on this phone. Sign back in '
      'with your name and everything is where you left it.';
  static const String signOutConfirm = 'Sign out';

  static const String signInTitle = 'What should we call you?';
  static const String signInBody =
      'RewireMind greets you by name and puts it on your profile. That is the '
      'whole of the account — there is nothing to verify and no password to '
      'forget.';
  static const String signInHint = 'Your name';
  static const String signInGo = 'Start';
  static const String signInPrivacy =
      'Stays on this phone. No email, no password, nothing uploaded.';

  // -- How it works ----------------------------------------------------------

  /// The app as five short slides: a drawing, a headline and one line.
  ///
  /// It was nine cards of sentences. Nobody reads nine cards of sentences in
  /// the first minute with an app, and this is shown in exactly that minute —
  /// so each slide says one thing, big, and a small drawing does the rest.
  static const List<HowSlide> howSlides = [
    HowSlide(
      'sprout',
      'Tiny habits.\nBig change.',
      'Small wins, every day, rewire your brain.',
      0xFF2E9E63,
    ),
    HowSlide(
      'tick',
      'Tap it.\nDone.',
      'Tick habits off, or count them up.',
      0xFF1F8FBF,
    ),
    HowSlide(
      'flame',
      'Streaks\nthat glow.',
      'Every perfect day keeps the flame alive.',
      0xFFE2603C,
    ),
    HowSlide(
      'grid',
      'Your story,\nin colour.',
      'Calendar, board and progress at a glance.',
      0xFF8B6FD1,
    ),
    HowSlide(
      'ring',
      '21 days\nto rewire.',
      'One path. One new you.',
      0xFF6D57C6,
    ),
  ];

  static const String howSkip = 'Skip';
  static const String howNext = 'Next';
  static const String howStart = "Let's go";
  static const String howTour = 'Show me around the app';

  static const List<ProfileMenuEntry> profileMenu = [
    ProfileMenuEntry(
      id: 'premium',
      title: PremiumContent.menuTitle,
      subtitle: PremiumContent.menuLine,
      iconKey: 'premium',
    ),
    ProfileMenuEntry(
      id: 'journal',
      title: 'Journal',
      subtitle: 'Your moods, words and what lifts you',
      iconKey: 'journal_menu',
    ),
    ProfileMenuEntry(
      id: 'appearance',
      title: 'Appearance',
      subtitle: 'How the page follows the time of day',
      iconKey: 'appearance',
    ),
    ProfileMenuEntry(
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Evening nudge and reminders',
      iconKey: 'notifications',
    ),
    ProfileMenuEntry(
      id: 'widgets',
      title: 'Home Screen',
      subtitle: 'Widgets for your home screen',
      iconKey: 'widgets',
    ),
    ProfileMenuEntry(
      id: 'onboarding',
      title: 'How it works',
      subtitle: 'Five quick slides',
      iconKey: 'help',
    ),
    ProfileMenuEntry(
      id: 'privacy',
      title: 'Export and import data',
      subtitle: 'Everything, as Excel or PDF',
      iconKey: 'privacy',
    ),
    ProfileMenuEntry(
      id: 'rate',
      title: 'Rate the app',
      subtitle: 'A minute of your time, and it helps',
      iconKey: 'about',
    ),
    ProfileMenuEntry(
      id: 'share_app',
      title: 'Share RewireMind',
      subtitle: 'Send it to a friend',
      iconKey: 'share_app',
    ),
    ProfileMenuEntry(
      id: 'feedback',
      title: 'Give feedback',
      subtitle: 'Tell us what to fix or add',
      iconKey: 'feedback',
    ),
    ProfileMenuEntry(
      id: 'about',
      title: 'About',
      subtitle: 'RewireMind, and the small print',
      iconKey: 'about',
    ),
    ProfileMenuEntry(
      id: 'sign_out',
      title: 'Sign out',
      subtitle: 'Your data stays on this phone',
      iconKey: 'sign_out',
    ),
    // Only in builds made with DEV_TOOLS; see kTestAppRow.
    ProfileMenuEntry(
      id: 'test_app',
      title: 'Test app',
      subtitle: 'Demo data, day 2, start over',
      iconKey: 'test_app',
    ),
  ];

  static const String testAppTitle = 'Test app';
  static const String testPremiumTitle = 'Turn premium on';
  static const String testPremiumBody =
      'Unlocks everything, as a paid copy of the app.';
  static const String testPremiumDone = 'Premium on.';
  static const String testFreeTitle = 'Back to free';
  static const String testFreeBody =
      'See what everybody else sees: $kFreeHabitLimit habits, no journal.';
  static const String testFreeDone = 'Back to the free tier.';

  static const String previewSendsTitle = 'See the evening notifications';
  static const String previewSendsBody =
      'Posts all four: two challenge days, and the catch-up with a streak '
      'and without.';
  static String previewSendsDone(int count) =>
      'Sent $count. Pull the shade down and expand one.';
  static const String previewSendsNeedsHabits =
      'Add a habit first — the evening send names what is left.';
  static const String freshTitle = 'Fresh install';
  static const String freshBody =
      'Everything wiped, as if just installed: sign in, slides and tour.';
  static const String freshConfirmTitle = 'Start from a fresh install?';
  static const String freshConfirmBody =
      'Every habit, your name and all settings are erased.';
  static const String freshConfirm = 'Wipe';
  static const String resetRowTitle = 'Start over';
  static const String resetRowBody = 'Clear every habit and begin again.';

  // -- Habit kinds ----------------------------------------------------------

  /// Home splits the list once the user has both kinds, because "did it" and
  /// "avoided it" are read very differently.
  static const String sectionBuild = 'Build';
  static const String sectionQuit = 'Cut back';

  static const String quitDone = 'Stayed under it';
  static const String quitPending = 'Not marked yet';
  static const String quitGoalLabel = 'One tick a day';

  // -- Discontinued habits --------------------------------------------------

  static const String discontinued = 'Discontinued';
  static const String discontinuedOn = 'Stopped';
  static const String detailDiscontinue = 'Discontinue habit';
  static const String detailResume = 'Resume habit';
  static const String detailDiscontinueTitle = 'Stop tracking this habit?';
  static const String detailDiscontinueBody =
      'It stops appearing from today. Its history stays, so past progress and '
      'streaks remain accurate.';
  static const String detailDiscontinueConfirm = 'Stop tracking';

  // -- Habit editor ---------------------------------------------------------

  static const String editorKindLabel = 'What are you changing?';
  static const String editorKindBuild = 'Build';
  static const String editorKindQuit = 'Cut back';

  static const String editorNewTitle = 'New habit';
  static const String editorEditTitle = 'Edit habit';
  static const String editorNameLabel = 'What do you want to build?';
  static const String editorNameHint = 'e.g. Read 10 pages';
  static const String editorIconLabel = 'Icon';
  static const String editorGoalLabel = 'Daily goal';
  static const String editorUnitLabel = 'Unit';
  static const String editorRepeatLabel = 'Repeat on';
  static const String editorEveryDay = 'Every day';
  static const String editorWeekdays = 'Weekdays';
  static const String editorSave = 'Save habit';
  static const String editorCreate = 'Create habit';
  static const String editorCancel = 'Cancel';
  static const String editorNameRequired = 'Give your habit a name';
  static const String editorTargetRequired = 'Goal must be more than zero';
  static const String editorDaysRequired = 'Pick at least one day';

  /// Units offered as quick picks in the editor.
  /// What a habit with no unit is called.
  ///
  /// The first entry in the measurement sheet, and the default: most habits
  /// are a thing you either did or did not, and the number field only appears
  /// once there is something for it to count.
  static const String goalJustDoIt = 'Just do it';

  /// Everything a habit can be measured in, grouped so a long list is
  /// scannable. One sheet rather than a row of chips: there is no end to this
  /// list, and a control that grows with it stops being a control.
  static const Map<String, List<String>> unitGroups = {
    'Time': ['min', 'hours'],
    'Count': ['times', 'reps', 'pages', 'steps'],
    'Distance': ['km', 'miles', 'm'],
    'Drink': ['glasses', 'litres', 'ml'],
    'Weight': ['kg', 'lb', 'g'],
    'Energy': ['cal', 'kcal'],
  };

  /// Every unit the picker knows, flattened — for deciding whether a habit's
  /// unit is one of ours or something the user typed.
  static List<String> get habitUnits => [
    for (final group in unitGroups.values) ...group,
  ];

  static const String editorLookLabel = 'Look';
  static const String editorLookBody = 'Icon and colour';

  static const String unitSheetTitle = 'Measured in';
  static const String unitPlainTitle = 'No measurement';
  static const String unitPlainBody = 'Tick it off, and that is the habit';

  static const String editorIconRow = 'Icon';
  static const String editorIconBody = 'How it looks in your list';
  static const String editorColourRow = 'Colour';

  /// Says what the colour is *for*. It is not decoration: it is the hue this
  /// habit wears on the board and in the progress breakdown, which is the
  /// only thing telling eight habits apart there.
  static const String editorColourBody = 'How it is shown on the board';
  static const String unitCustomLabel = 'Something else';
  static const String unitCustomHint = 'chapters, lengths, cigarettes…';
  static const String goalOther = 'Other';

  /// Short weekday initials for the repeat picker, Monday first.
  static const List<String> weekdayInitials = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  // -- Habit detail ---------------------------------------------------------

  static const String detailTodayTitle = "Today's progress";

  /// Short forms for the compact stat band on the detail screen, where the
  /// full labels would not fit three across.
  static const String detailStreakShort = 'streak';
  static const String detailBestShort = 'best';
  static const String detailCompletionShort = 'done';

  static const String detailMarkDone = 'Mark as done';
  static const String detailMarkUndone = 'Undo';

  /// What goes in the message when somebody shares the app.
  static String shareAppText(String link) =>
      'I am building better habits with RewireMind. Try it: $link';

  static const String boardEarlier = 'Earlier days';
  static const String boardLater = 'Later days';

  static const String calendarViewOverview = 'Overview';
  static const String calendarViewBoard = 'Board';

  // -- the Home tour ---------------------------------------------------------

  static const String coachSkip = 'Skip';
  static const String coachNext = 'Next';
  static const String coachDone = 'Start';
  static const String coachTapNext = 'Tap anywhere to continue';
  static const String coachTapDone = 'Tap to finish';
  static String coachCount(int at, int of) => '$at of $of';

  static const String coachHeroTitle = 'Meet your brain';
  static const String coachHeroBody =
      'It lives your day, and cheers when you finish.';
  static const String coachStatsTitle = 'Your streak';
  static const String coachStatsBody = 'Perfect days in a row. Keep it going.';
  static const String coachWeekTitle = 'Your week';
  static const String coachWeekBody = 'Tap a day to see it or fill it in.';
  static const String coachHabitsTitle = 'Your habits';
  static const String coachHabitsBody =
      'Tap the circle when done. Hold for notes.';
  static const String coachJournalTitle = 'Check in';
  static const String coachJournalBody =
      'One tap on how you feel. Words are optional.';
  static const String coachAddTitle = 'Add a habit';
  static const String coachAddBody = 'Start small. Two or three is plenty.';
  static const String coachTabsTitle = 'Explore';
  static const String coachTabsBody = 'Calendar, progress and your profile.';

  static const String detailNoteDeleted = 'Note deleted';
  static const String detailNoteDelete = 'Delete note';

  static const String detailHistoryTitle = 'History';

  /// The spans a habit's history can be shown over.
  static const String historySpanWeek = 'This week';
  static const String historySpanMonth = 'Last 4 weeks';
  static const String historySpanAll = 'All time';

  /// "7 – 13 Sep" under the picker, so the grid always says which days it is.
  static String historyRange(String from, String to) => '$from – $to';
  static const String detailNotesTitle = 'Notes';
  static const String detailNotesSubtitle =
      'What you wrote on the day. Tap one to edit it.';

  /// "Show all 9 notes"
  static String detailNotesShowAll(int n) => 'Show all $n notes';
  static const String detailNotesShowFewer = 'Show fewer';

  /// The grid is a record and nothing else, so this says how to read it
  /// rather than what to do with it — it used to end "tap a day to open it
  /// above", which stopped being true when the grid stopped taking taps.
  static const String detailHistorySubtitle =
      'Deeper colour, more of it done that day.';

  static const String detailCurrentStreak = 'Current streak';
  static const String detailBestStreak = 'Best streak';
  static const String detailCompletion = 'Completion';
  static const String detailScheduleEveryDay = 'Every day';
  static const String detailDelete = 'Delete habit';
  static const String detailDeleteTitle = 'Delete this habit?';
  static const String detailDeleteBody =
      'Its history will be removed too. This cannot be undone.';
  static const String detailDeleteConfirm = 'Delete';
  static const String detailSince = 'Tracking since';

  /// "2 L per day", "10 pages per day"
  static String targetSummary(String target, String unit) =>
      unit.isEmpty ? '$target per day' : '$target $unit per day';

  // -- Day selection / backfill ---------------------------------------------

  static const String daySheetFuture = "This day hasn't happened yet";
  static const String daySheetNothing = 'No habits scheduled for this day';
  static const String dayBackToToday = 'Back to today';

  /// "3 of 5 completed"
  static String completedOf(int done, int total) => '$done of $total completed';

  // -- Navigation -----------------------------------------------------------

  static const String navHome = 'Home';
  static const String navCalendar = 'Calendar';
  static const String navProgress = 'Progress';
  static const String navProfile = 'Profile';
}

/// Per-range copy for the Progress tab.
class ProgressCopy {
  const ProgressCopy({
    required this.subtitle,
    required this.script,
    required this.chartTitle,
    required this.chartSubtitle,
    required this.breakdownSubtitle,
    required this.comparisonLabel,
    required this.bannerTitle,
    required this.bannerVerb,
    required this.bannerTail,
  });

  final String subtitle;

  /// Handwritten annotation in the header.
  final String script;

  final String chartTitle;
  final String chartSubtitle;
  final String breakdownSubtitle;

  /// Label on the fourth stat tile ("vs. Last Week").
  final String comparisonLabel;

  final String bannerTitle;
  final String bannerVerb;
  final String bannerTail;

  /// "You completed 25 out of 35 scheduled habits (71%). Keep going, …"
  String banner(String done, String total, int percent) =>
      '$bannerVerb $done out of $total scheduled habits ($percent%). $bannerTail';
}

/// One row in the Profile settings list.
class ProfileMenuEntry {
  const ProfileMenuEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
}

/// One slide of How it works.
class HowSlide {
  const HowSlide(this.art, this.title, this.line, this.colour);

  /// Which drawing the slide shows: sprout, tick, flame, grid or ring.
  final String art;

  /// Two short lines, split where the break should fall.
  final String title;
  final String line;

  /// The slide's own glow and button colour.
  final int colour;
}
