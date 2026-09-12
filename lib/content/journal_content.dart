import 'package:flutter/material.dart';

/// ============================================================================
/// THE JOURNAL'S WORDS
/// ============================================================================
/// Built on what makes people stop journaling: the blank page, friction, and
/// entries that go nowhere. So every entry starts from a prompt rather than
/// an empty screen, the shortest one is a single tap on a face, and what is
/// written comes back as patterns — which habits lift the mood.
///
/// The prompts lean on the practices with the steadiest evidence behind them
/// (gratitude, "three good things", an intention for the day) and ask about
/// wins as well as troubles, so the journal is worth opening on good days too.
/// ============================================================================

/// A mood on the five-point scale.
@immutable
class JournalMood {
  const JournalMood(this.value, this.label, this.icon, this.colour);

  final int value;
  final String label;
  final IconData icon;
  final int colour;
}

/// A set of prompts an entry is written against.
@immutable
class JournalTemplate {
  const JournalTemplate({
    required this.key,
    required this.name,
    required this.icon,
    required this.prompts,
    required this.blurb,
  });

  final String key;
  final String name;
  final IconData icon;

  /// One line under the name, on the picker.
  final String blurb;

  /// Prompt key and the question itself, in order.
  final List<(String, String)> prompts;
}

class JournalContent {
  const JournalContent._();

  static const String title = 'Journal';

  static const List<JournalMood> moods = [
    JournalMood(
      1,
      'Rough',
      Icons.sentiment_very_dissatisfied_rounded,
      0xFFE0736B,
    ),
    JournalMood(2, 'Low', Icons.sentiment_dissatisfied_rounded, 0xFFEE9B55),
    JournalMood(3, 'Okay', Icons.sentiment_neutral_rounded, 0xFFE6C24F),
    JournalMood(4, 'Good', Icons.sentiment_satisfied_rounded, 0xFF72B86F),
    JournalMood(5, 'Great', Icons.sentiment_very_satisfied_rounded, 0xFF2E9E6E),
  ];

  static JournalMood mood(int value) => moods[(value - 1).clamp(0, 4)];

  /// Feeling keys and how they read. Short on purpose: a tap, not a search.
  static const List<(String, String)> feelings = [
    ('calm', 'Calm'),
    ('grateful', 'Grateful'),
    ('proud', 'Proud'),
    ('motivated', 'Motivated'),
    ('happy', 'Happy'),
    ('focused', 'Focused'),
    ('tired', 'Tired'),
    ('anxious', 'Anxious'),
    ('stressed', 'Stressed'),
    ('sad', 'Sad'),
    ('frustrated', 'Frustrated'),
    ('lonely', 'Lonely'),
  ];

  static String feeling(String key) =>
      feelings.firstWhere((f) => f.$1 == key, orElse: () => (key, key)).$2;

  /// In the order they are offered: the blank page first, because it is the
  /// one that asks nothing of you, then the two that look for good news, then
  /// the two with a time of day attached. Four, so they sit two by two on a
  /// phone with nothing scrolled out of sight.
  static const List<JournalTemplate> templates = [
    JournalTemplate(
      key: 'free',
      name: 'Free write',
      icon: Icons.edit_note_rounded,
      blurb: 'Anything at all.',
      prompts: [('text', "What's on your mind?")],
    ),
    JournalTemplate(
      key: 'gratitude',
      name: 'Three good things',
      icon: Icons.volunteer_activism_outlined,
      blurb: 'What went well, and why.',
      prompts: [
        ('good1', 'One good thing'),
        ('good2', 'Another'),
        ('good3', 'And one more'),
      ],
    ),
    JournalTemplate(
      key: 'morning',
      name: 'Morning intention',
      icon: Icons.wb_twilight_rounded,
      blurb: 'Set the day first.',
      prompts: [
        ('grateful', "I'm grateful for…"),
        ('great', 'Today will be great if…'),
        ('protect', 'The one habit I will protect today'),
      ],
    ),
    JournalTemplate(
      key: 'evening',
      name: 'Evening reflection',
      icon: Icons.nights_stay_outlined,
      blurb: 'Three lines to close it.',
      prompts: [
        ('win', 'A win today, however small'),
        ('hard', 'What got in the way?'),
        ('tomorrow', 'Tomorrow, I will…'),
      ],
    ),
  ];

  /// A mood with no words: what a tap on a face from Home makes.
  static const JournalTemplate checkIn = JournalTemplate(
    key: 'checkin',
    name: 'Check-in',
    icon: Icons.mood_rounded,
    blurb: 'Just the mood.',
    prompts: [('note', 'A word about it?')],
  );

  static JournalTemplate template(String key) => [
    ...templates,
    checkIn,
  ].firstWhere((t) => t.key == key, orElse: () => templates.last);

  /// Morning before noon, the evening's questions after five, and in between
  /// the one with no clock in it.
  static JournalTemplate suggestedFor(DateTime now) {
    if (now.hour < 12) return template('morning');
    if (now.hour >= 17) return template('evening');
    return template('gratitude');
  }

  /// For Free write, when the page is empty. Shuffled with a tap.
  static const List<String> freePrompts = [
    'What would make tomorrow 1% better?',
    'What did you avoid today, and why?',
    'When did you feel most like yourself this week?',
    'What habit is quietly getting easier?',
    'What would you tell yourself from a month ago?',
    'What drained you today? What refilled you?',
    'What are you proud of that nobody saw?',
    'Where did you choose the harder, better thing?',
    'What does your best possible self do tomorrow morning?',
    'What is one thing you can let go of?',
    'What surprised you today?',
    'Who made today better, and did they know it?',
  ];

  // -- screens --------------------------------------------------------------

  // Short: the ask shares one line with the five faces.
  static const String homeAsk = "How's today?";
  static const String homeAskEvening = 'How was today?';
  static const String homeAskPast = 'How was it?';
  static const String homeSaved = 'Saved to your journal';
  static const String homeAddWords = 'Add a few words';
  static const String homeOpen = 'Journal';
  static const String homeChange = 'Change how the day felt';

  static const String entriesTab = 'Entries';
  static const String insightsTab = 'Insights';
  static const String write = 'Write';
  static const String searchHint = 'Search your journal';
  static const String noResults = 'Nothing matches that.';

  static const String emptyTitle = 'Your journal starts here';
  static const String emptyBody =
      'A tap on a face is an entry. Words are a bonus.';

  static const String onThisDay = 'On this day';
  static String onThisDayWhen(int months) => months >= 12
      ? '${months ~/ 12} ${months >= 24 ? 'years' : 'year'} ago'
      : '$months ${months == 1 ? 'month' : 'months'} ago';

  static const String editorNew = 'New entry';
  static const String editorEdit = 'Entry';
  static const String editorMood = 'How are you feeling?';
  static const String editorFeelings = 'Anything else?';
  static const String editorSave = 'Save';
  static const String editorDelete = 'Delete entry';
  static const String editorDeleted = 'Entry deleted';
  static const String editorShuffle = 'Another prompt';
  static const String editorPickDay = 'Change day';
  static const String editorDiscardTitle = 'Discard this entry?';
  static const String editorDiscardBody = 'What you wrote here will be lost.';
  static const String editorDiscard = 'Discard';
  static const String editorKeep = 'Keep writing';

  static String context(int done, int total, int streak) {
    final habits = total == 0 ? 'No habits due' : '$done of $total habits';
    return streak >= 2 ? '$habits · 🔥 $streak-day streak' : habits;
  }

  // -- insights -------------------------------------------------------------

  static const String insightsMonth = 'Mood this month';
  static const String insightsTrend = 'Last 8 weeks';
  static const String insightsLift = 'Habits that lift your mood';
  static const String insightsLiftBody =
      'Your mood on days you did each habit, against days you did not.';
  static const String insightsLiftEmpty =
      'A couple of weeks of check-ins and this fills in.';
  static const String insightsFeelings = 'What you feel most';
  static const String insightsEntries = 'entries';
  static const String insightsAverage = 'average mood';
  static const String insightsEmptyTitle = 'Patterns show up here';
  static const String insightsEmptyBody =
      'Check in for a few days and see what lifts your mood.';

  static String lift(double delta) =>
      '${delta >= 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)} mood';
}
