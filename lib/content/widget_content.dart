import 'dart:math';

/// ============================================================================
/// WHAT THE HOME SCREEN WIDGET SAYS
/// ============================================================================
/// The widget is the only part of the app that speaks to somebody who is not
/// using it. That changes the register: a reminder can be businesslike because
/// you asked for it, but this is sitting on a home screen among photographs of
/// people's families, and it earns its place by being good company.
///
/// So the character talks rather than the app. It is pleased when the day is
/// done, it asks when the day has not started, and when it has not seen anybody
/// for a while it says so — because that is the honest thing for it to feel and
/// because "Gone?" gets a tap where "Complete your habits" does not.
///
/// Every line comes in two lengths. The strip is one cell tall and four across,
/// with a mascot and a chip already in that row, and there is no width left for
/// a sentence — so rather than cutting a good line off with an ellipsis, each
/// thought is written twice and the narrow sizes get the short one.
///
/// Nothing here may run past its box. Keeping to that is a pact between three
/// things: these lines stay short, every text view on the widget shrinks its
/// own type to fit (`autoSizeTextType`), and every one of them ends in an
/// ellipsis if even that is not enough. It was not always so — "Finish today to
/// start a streak" arrived on a home screen as "Finish today to start a", which
/// is worse than saying nothing.
/// ============================================================================

/// How the character is drawn on the widget.
///
/// Only three, and deliberately: this says how the *week* is going, and the
/// widget crosses it with the time of day to land on one of six characters —
/// a nudge in the morning is the brain brushing its teeth, a nudge at night is
/// the brain already in bed. The moods that are worth saying whatever the hour
/// are the two at the ends, and those override the clock.
enum WidgetMood { happy, nudge, sad }

/// One thought, at both lengths.
class WidgetLine {
  const WidgetLine(this.long, this.short);

  /// For the sizes with a column of their own to fill.
  final String long;

  /// For the strip and the square, where there is room for a couple of words.
  final String short;
}

/// Everything the widget shows, decided here rather than in Kotlin.
class WidgetFace {
  const WidgetFace({
    required this.line,
    required this.shortLine,
    required this.sub,
    required this.streak,
    required this.streakShort,
    required this.mood,
    required this.pool,
  });

  final String line;
  final String shortLine;

  /// The quieter line under it: what is actually outstanding.
  final String sub;

  /// The chip on the right: the challenge if one is running, otherwise
  /// whichever true thing about today is worth the space.
  final String streak;

  /// The same, for the sizes where the chip shares its row.
  final String streakShort;

  final WidgetMood mood;

  /// Every line that fits this moment, not just the one showing.
  ///
  /// The widget picks out of this by the hour, so that a home screen the app
  /// has not been opened on since breakfast still has something new to say by
  /// lunchtime. Dart keeps the writing; the hour only chooses.
  final List<WidgetLine> pool;

  /// The pool as the widget stores it: one line per row, longs or shorts.
  String get lines => pool.map((l) => l.long).join('\n');

  String get linesShort => pool.map((l) => l.short).join('\n');
}

class WidgetContent {
  const WidgetContent._();

  /// Said before there is anything to track.
  ///
  /// Without this a fresh install reads "Still there?" over a sad face, which
  /// is nonsense addressed to somebody who arrived a minute ago: nothing has
  /// been logged, so the "days since we saw you" count is at its maximum and
  /// the widget concludes it has been abandoned.
  /// Encouragement rather than an instruction. On the day it is installed the
  /// widget has no streak to report and nothing to nudge about, so what it can
  /// usefully do is give somebody a reason — and a home screen is a better
  /// place for a good sentence than for a to-do.
  static const List<WidgetLine> firstRun = [
    WidgetLine('Small steps, every day.', 'Small steps.'),
    WidgetLine('Start where you are.', 'Start here.'),
    WidgetLine('One habit is enough.', 'Just one.'),
    WidgetLine('Begin badly. Begin anyway.', 'Begin!'),
  ];

  /// Said when the day is finished.
  static const List<WidgetLine> done = [
    WidgetLine('All done today.', 'Day won.'),
    WidgetLine('Look at you go.', 'Nailed it.'),
    WidgetLine('Nothing left. Rest.', 'All of it.'),
    WidgetLine('Clean sweep. Sit down.', 'Clean sweep.'),
  ];

  /// Said partway through a day.
  static const List<WidgetLine> partway = [
    WidgetLine('Good start.', 'Good start.'),
    WidgetLine('Keep going?', 'Keep going.'),
    WidgetLine('Nearly there.', 'Nearly!'),
    WidgetLine('On a roll now.', 'On a roll.'),
  ];

  /// Said on a day nothing has been logged yet, while the run is alive.
  ///
  /// Three pools rather than one, because this is the state the widget spends
  /// most of its life in and the state where the character is chosen by the
  /// clock. A brain in bed asking "Got a minute?" is a picture and a sentence
  /// that were written by two people who never met. Every line here is worth
  /// reading twice next to the face it comes with.
  ///
  /// [waiting] is the middle of the day and the default, so a phase this does
  /// not recognise still gets something sensible.

  /// 5am to 10am, over a brain brushing its teeth.
  static const List<WidgetLine> waitingMorning = [
    WidgetLine('Morning. Shall we?', 'Morning!'),
    WidgetLine('Brush. Then begin.', 'Then begin.'),
    WidgetLine('New day, clean slate.', 'Clean slate.'),
    WidgetLine('Up early. Nice.', 'Up early!'),
  ];

  /// 10am to 7pm, over a brain out for a run.
  static const List<WidgetLine> waiting = [
    WidgetLine('Got a minute?', 'Got a minute?'),
    WidgetLine('Warmed up. You?', 'Warmed up!'),
    WidgetLine('Today, then?', 'Today?'),
    WidgetLine('I am going. Coming?', 'Coming?'),
  ];

  /// 7pm to 5am, over a brain already in bed.
  static const List<WidgetLine> waitingNight = [
    WidgetLine('One more before bed?', 'Before bed?'),
    WidgetLine('Day is not over yet.', 'Not over yet.'),
    WidgetLine('Sneak one in?', 'Sneak one in?'),
    WidgetLine('I waited up for you.', 'I waited up.'),
  ];

  /// The pool for an hour of the day. Takes [DayPhase.name] as Dart writes it
  /// to the widget, and falls back to the daytime pool for anything else.
  static List<WidgetLine> waitingFor(String phase) => switch (phase) {
    'earlyMorning' => waitingMorning,
    'night' => waitingNight,
    _ => waiting,
  };

  /// Said when a day has already been missed.
  ///
  /// Named rather than general where a name is known: the difference between a
  /// notification and somebody noticing is whether it knows who you are. The
  /// short forms drop the name, because on a two-cell square there is room for
  /// one word and it had better be the one that stings.
  static List<WidgetLine> missed(String? name) => [
    WidgetLine(
      name == null ? 'I miss you.' : 'I miss you, $name.',
      'Miss you.',
    ),
    const WidgetLine('Gone?', 'Gone?'),
    const WidgetLine('Too busy?', 'Too busy?'),
    const WidgetLine('Still there?', 'Still there?'),
  ];

  /// Picks a thought that is not the one showing, so an update visibly changes
  /// something. With one line in the pool that is impossible, so it gives up
  /// rather than looping.
  static WidgetLine pick(List<WidgetLine> from, String? avoid, Random rng) {
    if (from.length < 2) return from.first;
    for (var tries = 0; tries < 6; tries++) {
      final line = from[rng.nextInt(from.length)];
      if (line.long != avoid) return line;
    }
    return from.first;
  }

  /// The quieter line under the chip, on the one size wide enough for it.
  ///
  /// This is where the streak went when the chip took over the count. Both
  /// were competing to be the number on the widget and the count won: a streak
  /// is a thing to be pleased about, and what somebody glances at a home
  /// screen for is what they still owe today.
  static String sub({
    int? challengeDay,
    required int pathLength,
    required int streak,
    required int total,
  }) {
    if (challengeDay != null) {
      return 'Challenge · day ${challengeDay.clamp(0, pathLength)} of $pathLength';
    }
    // Two days, not one. "1 day streak" congratulates somebody on having
    // opened the app. And it says what the days were: "10 days in a row" on
    // its own left people asking ten days of what.
    if (streak >= 2) return '🔥 $streak days, all done';
    if (total == 0) return 'Nothing due today';
    return 'A streak starts today';
  }

  static String streakChip(int done, int total) => 'Day $done of $total';

  /// For the strip and the square, where the chip shares a row.
  static String streakChipShort(int done, int total) => '$done/$total';

  /// What goes in the chip, on every size.
  ///
  /// One question, asked the same way on all three: how much of today is
  /// still owed. It used to be the challenge, which meant a widget belonging
  /// to somebody who had never opened the challenge sat there saying "Day 0 of
  /// 21" for months — an accusation about a thing they had declined — and then
  /// a streak, which is a fact about last week.
  ///
  /// When the answer is none it says so once and stops counting. A widget that
  /// keeps reporting "4 of 4" at somebody who finished at nine in the morning
  /// is a widget still asking for something.
  static WidgetLine chip({
    required int doneToday,
    required int scheduledToday,
  }) {
    // Says what is being counted. "8 to go" was a number without a noun, and
    // a home screen gives nobody the context to supply one.
    if (scheduledToday <= 0) {
      return const WidgetLine('Nothing today', 'Nothing today');
    }
    final left = (scheduledToday - doneToday).clamp(0, scheduledToday);
    if (left == 0) return const WidgetLine('All done ✓', 'All done ✓');
    final label = left == 1 ? '1 habit left' : '$left habits left';
    return WidgetLine(label, label);
  }
}
