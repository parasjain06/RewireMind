import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/habit_shade.dart';
import 'day_strip.dart';
import 'empty_state.dart';
import 'k_card.dart';
import 'tracking_guard.dart';
import 'share_board.dart';

/// How large to draw the board.
///
/// Blocks touch on all four sides. Tiles with gaps between them read as a grid
/// of chips you are meant to count; blocks with no gap at all read as one field
/// of colour, which is the thing the eye can take in without counting.
class BoardMetrics {
  const BoardMetrics({
    required this.cell,
    required this.row,
    required this.names,
    required this.header,
    required this.nameSize,
  });

  /// One day across, one habit down.
  final double cell;
  final double row;

  /// The pinned column of names, and the size its text is set at.
  final double names;
  final double nameSize;

  final double header;

  /// The only size there is. There was briefly a smaller one for the Calendar
  /// too, but a board that had to shrink to fit under a month grid could no
  /// longer show the shading it exists for, so the Calendar kept its table.
  /// The same board with a different day width.
  ///
  /// Used to stretch the days a little so the strip holds a whole number of
  /// them — see [_HabitBoardState.build].
  BoardMetrics withCell(double width) => BoardMetrics(
    cell: width,
    row: row,
    names: names,
    header: header,
    nameSize: nameSize,
  );

  static const BoardMetrics roomy = BoardMetrics(
    cell: 43,
    row: 41,
    names: 112,
    header: 46,
    nameSize: 13,
  );
}

/// The habit board: names down the left, days across the right.
///
/// A different question from the list. The list answers "what do I do today",
/// which is why it is the default; the board answers "how have I actually been
/// doing", and it answers it without a single number — a fortnight of solid
/// colour and a fortnight of pale smudges look nothing alike from across the
/// room.
///
/// Intensity carries the amount, not just the fact. Two glasses of water out of
/// five is a pale band, not a missing one, because a day where you did
/// something is not the same as a day where you did nothing and the list cannot
/// show that difference at all once the day is over.
///
/// The days butt together with no gap between them. Drawn as separate tiles it
/// read as a grid of chips you were meant to count; drawn as one continuous
/// band per habit it reads as a strip of colour that gets darker and lighter,
/// which is the thing the eye is actually good at.
class HabitBoard extends StatefulWidget {
  const HabitBoard({
    super.key,
    required this.onOpenDay,
    required this.onOpenDate,
    this.metrics = BoardMetrics.roomy,
    this.showShare = true,
  });

  /// Tapping a habit's name opens it, the same as tapping its row in the list.
  /// Called with the habit and the day that was pressed.
  ///
  /// A block used to tick its own day, which is wrong twice over: on a habit
  /// with a target it had to guess whether a part-done day meant finished or
  /// abandoned, and a field of colour gives no hint that pressing it writes
  /// anything. Pressing one now opens that habit at that day.
  final void Function(Habit habit, DateTime day) onOpenDay;

  /// Called with the date whose column heading was pressed.
  ///
  /// The board is seventy days wide, which makes it the fastest way in the
  /// app to reach a particular one — but only if the dates across the top do
  /// something when you press them.
  final void Function(DateTime day) onOpenDate;

  /// How many days the board holds. Ten weeks, so the columns line up under
  /// their weekday letters and there is enough history to see a pattern in.
  static const int days = 70;

  /// Whether the legend carries the share button.
  ///
  /// Off inside the share screen itself, where the board *is* the picture —
  /// a share button in a photograph of a share button is a joke nobody meant
  /// to make.
  final bool showShare;

  /// How big to draw it.
  ///
  /// Two sizes, because the board appears in two places with very different
  /// amounts of room. On Home it has the screen; on the Calendar it sits under
  /// a month grid that takes most of the height, and at Home's size exactly
  /// one habit fitted — a board showing one row is not a board.
  final BoardMetrics metrics;

  /// How deep a day is drawn, from how much of it was done.
  ///
  /// The ramp itself lives in `theme/habit_shade.dart` now: the Calendar, the
  /// progress breakdown and the history grid inside a habit all draw days the
  /// same way, and three copies of one curve is three chances for them to
  /// drift apart.
  static double intensity(double fraction) => shadeAlpha(fraction);

  @override
  State<HabitBoard> createState() => _HabitBoardState();
}

class _HabitBoardState extends State<HabitBoard> with DayStripScroll {
  /// What the share button photographs.
  final GlobalKey _shot = GlobalKey();

  Future<void> _share(BuildContext context) =>
      BoardShare.send(context, boundary: _shot);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final habits = state.habits;
    final m = widget.metrics;

    if (habits.isEmpty) return const _BoardEmpty();

    final today = state.today;
    final days = [
      for (var i = HabitBoard.days - 1; i >= 0; i--)
        today.subtract(Duration(days: i)),
    ];

    // On its own card, like the table it replaces on the Calendar. Bare, it
    // floated under the white month card above it with nothing to line up
    // against — and the gaps in the mosaic showed the page's own blue, where
    // against white they read as what they are: days with nothing in them.
    // Held to the top and sized to its rows. It used to be handed the rest of
    // the screen and fill it, which left a band of empty card under the last
    // habit — the board looked unfinished rather than short.
    return Align(
      alignment: Alignment.topCenter,
      child: RepaintBoundary(
        key: _shot,
        child: KCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: LayoutBuilder(
            builder: (context, box) => _grid(
              context,
              state,
              habits,
              days,
              today,
              // Whole days only. The strip is whatever width is left after the
              // names, and at the nominal day width it almost never held a
              // whole number of them, so its left edge cut a column in half.
              // Stretching each day by a pixel or two puts that edge on a
              // boundary.
              m.withCell(
                (box.maxWidth - m.names) /
                    math.max(1, ((box.maxWidth - m.names) / m.cell).floor()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    AppState state,
    List<Habit> habits,
    List<DateTime> days,
    DateTime today,
    BoardMetrics m,
  ) {
    dayWidth = m.cell;
    final rows = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The names, pinned across. This column is the reason the
        // board is readable at all: scroll the days and you can still
        // see whose row you are on.
        SizedBox(
          width: m.names,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final habit in habits)
                _NameCell(
                  habit: habit,
                  colour: state.colorFor(habit),
                  m: m,
                  onTap: () => widget.onOpenDay(habit, today),
                ),
            ],
          ),
        ),
        Expanded(
          child: EdgeFade(
            left: earlier,
            right: later,
            child: ScrollConfiguration(
              // The bar would lie across the bottom band, and this
              // scrolls by dragging anyway.
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: stripBody,
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final habit in habits)
                      _HabitStreak(
                        habit: habit,
                        days: days,
                        colour: state.colorFor(habit),
                        state: state,
                        m: m,
                        onOpenDay: widget.onOpenDay,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // What the whole thing means, said once, across the top of it.
        //
        // This used to be 9.5pt right-aligned in the section header outside
        // the card, on two lines, competing with the title and the view
        // switch — the one sentence that explains the board, in the least
        // readable place on the screen.
        _BoardLegend(onShare: widget.showShare ? () => _share(context) : null),
        const SizedBox(height: 8),
        // The dates, pinned above and dragged along by the rows.
        Row(
          children: [
            SizedBox(
              width: m.names,
              height: m.header,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppContent.boardNamesHeader,
                  style: context.k.text.captionStrong.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: context.k.colors.textMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                // The arrows sit half outside the dates, in the gutter beside
                // them, so neither one covers a day's label.
                clipBehavior: Clip.none,
                children: [
                  SingleChildScrollView(
                    controller: stripHead,
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    physics: const NeverScrollableScrollPhysics(),
                    child: _DateHeader(
                      days: days,
                      today: today,
                      m: m,
                      onOpenDate: widget.onOpenDate,
                    ),
                  ),
                  // Arrows at whichever ends have more days behind them. A
                  // strip that simply stops at the card's edge reads as all
                  // there is; these say there is more, and which way.
                  if (earlier)
                    Positioned(
                      left: -16,
                      top: 0,
                      bottom: 0,
                      child: StepArrow(
                        back: true,
                        tooltip: AppContent.boardEarlier,
                        onTap: () => stepWeek(back: true),
                      ),
                    ),
                  if (later)
                    Positioned(
                      right: -8,
                      top: 0,
                      bottom: 0,
                      child: StepArrow(
                        back: false,
                        tooltip: AppContent.boardLater,
                        onTap: () => stepWeek(back: false),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        // The habits scroll under the dates rather than taking the page with
        // them, so the column of dates is still there when you are twenty
        // habits down. Flexible rather than Expanded: a board of four habits
        // is four rows tall, and only a long one needs to scroll.
        Flexible(child: SingleChildScrollView(child: rows)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.days,
    required this.today,
    required this.m,
    required this.onOpenDate,
  });

  final List<DateTime> days;
  final DateTime today;
  final BoardMetrics m;
  final void Function(DateTime day) onOpenDate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: m.header,
      child: Row(
        children: [
          for (final day in days)
            _DateCell(
              day: day,
              isToday: day == today,
              m: m,
              onTap: () => onOpenDate(day),
            ),
        ],
      ),
    );
  }
}

/// One date over its column, with today ringed.
class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.isToday,
    required this.m,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final BoardMetrics m;

  /// Opens that whole day: what was scheduled, what got done, how much of it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return SizedBox(
      width: m.cell,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).toUpperCase(),
              style: k.text.caption.copyWith(
                fontSize: 9,
                letterSpacing: 0.5,
                color: k.colors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            // Today gets a filled disc rather than a coloured numeral. The
            // blocks below carry every other colour on the screen, so a tinted
            // digit up here would just be one more of them.
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: k.colors.accent,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: k.text.captionStrong.copyWith(
                  fontSize: 13,
                  color: isToday ? Colors.white : k.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.habit,
    required this.colour,
    required this.onTap,
    required this.m,
  });

  final Habit habit;
  final Color colour;
  final VoidCallback onTap;
  final BoardMetrics m;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return SizedBox(
      height: m.row,
      child: InkWell(
        onTap: onTap,
        // No colour chip beside the name. The blocks opposite are the
        // habit's colour at full width — a swatch here as well was saying the
        // same thing twice and stealing room from the name.
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              habit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: k.text.caption.copyWith(
                fontSize: m.nameSize,
                height: 1.2,
                color: k.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One habit's whole history, as a single unbroken band.
class _HabitStreak extends StatelessWidget {
  const _HabitStreak({
    required this.habit,
    required this.days,
    required this.colour,
    required this.state,
    required this.m,
    required this.onOpenDay,
  });

  final Habit habit;
  final List<DateTime> days;
  final Color colour;
  final AppState state;
  final BoardMetrics m;
  final void Function(Habit habit, DateTime day) onOpenDay;

  @override
  Widget build(BuildContext context) {
    // One tile per day, each in its own gutter. This was a mosaic — blocks
    // meeting edge to edge, empty days left as nothing — and it read as slabs
    // of colour with holes in them rather than as a grid: nothing lined up
    // under its date, and a habit with one good day was a lone block floating
    // in space.
    return SizedBox(
      height: m.row,
      child: Row(
        children: [
          for (final day in days)
            _Band(
              habit: habit,
              day: day,
              colour: colour,
              state: state,
              m: m,
              onOpenDay: onOpenDay,
            ),
        ],
      ),
    );
  }
}

/// The board's own caption: a strip of the ramp, and the sentence it proves.
///
/// Drawn from a real habit colour rather than grey, so the swatch is the same
/// material as the blocks below it. The ends are labelled because a gradient
/// on its own does not say which way round it goes.
class _BoardLegend extends StatelessWidget {
  const _BoardLegend({required this.onShare});

  /// Sends the board as a picture. On the legend row rather than in the header
  /// above it, because it is the board that gets shared, not the screen — and
  /// this row is already the board's own caption. Null inside the share screen,
  /// where the board is the picture.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final habits = state.habits;
    // The first habit's hue, so the legend belongs to the board under it
    // rather than being a grey specimen from somewhere else.
    final base = habits.isEmpty
        ? k.colors.accent
        : state.colorFor(habits.first);

    return Row(
      children: [
        Expanded(
          child: Text(
            AppContent.boardLegend,
            style: k.text.captionStrong.copyWith(
              fontSize: 11.5,
              color: k.colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppContent.boardLegendLow,
          style: k.text.caption.copyWith(fontSize: 9.5),
        ),
        const SizedBox(width: 5),
        Container(
          width: 62,
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              // The true ends of the ramp: the palest a block ever gets is the
              // floor, not transparent, so the swatch starts there.
              colors: [habitShade(base, 0), habitShade(base, 1)],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          AppContent.boardLegendHigh,
          style: k.text.caption.copyWith(fontSize: 9.5),
        ),
        if (onShare != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onShare,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.ios_share, size: 16, color: k.colors.primary),
            ),
          ),
        ],
      ],
    );
  }
}

/// One habit on one day: a slice of the band.
class _Band extends StatelessWidget {
  const _Band({
    required this.habit,
    required this.day,
    required this.colour,
    required this.state,
    required this.m,
    required this.onOpenDay,
  });

  final Habit habit;
  final DateTime day;
  final Color colour;
  final AppState state;
  final BoardMetrics m;
  final void Function(Habit habit, DateTime day) onOpenDay;

  void _tap(BuildContext context) {
    HapticFeedback.selectionClick();
    // A day before the habit began — or after it stopped, or off its
    // schedule — has nothing to open: the overview says what the faint cells
    // are when one is tapped, and this says the same thing.
    if (!habit.isActiveOnDay(day)) {
      showUntrackedNote(context, habit, day);
      return;
    }
    onOpenDay(habit, day);
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = habit.isActiveOnDay(day);
    final fraction = doneFraction(habit, state.valueOf(habit.id, day));

    final track = context.k.colors.accentTrack;

    // Every day is a tile, so the grid is there whether or not anything was
    // done. What changes is what is in it:
    final Color fill;
    if (!habit.isWithinLifetime(day)) {
      // Outside the habit's life altogether — before it started, or after it
      // was discontinued. Barely there, so the day the habit begins is the
      // day its row begins.
      fill = track.withValues(alpha: 0.06);
    } else if (!scheduled) {
      // Never asked for, so not a miss: the faintest tile there is, which
      // keeps a weekday-only habit's weekends in the grid without reading as
      // five failures every week.
      fill = track.withValues(alpha: 0.18);
    } else if (fraction == 0) {
      // Asked for and nothing done: the bare track, the same one the history
      // grid inside a habit uses, so an empty day looks the same everywhere.
      fill = track.withValues(alpha: 0.5);
    } else {
      fill = habitShade(colour, fraction);
    }

    return GestureDetector(
      onTap: () => _tap(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: m.cell,
        height: m.row,
        child: Padding(
          // The gutter: two pixels all round, so four between neighbours in
          // both directions and every tile sits squarely under its date.
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        // Today is marked in the date header rather than on the tiles. A dot
        // in the middle of one reads as a bullet hole.
      ),
    );
  }
}

class _BoardEmpty extends StatelessWidget {
  const _BoardEmpty();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.topCenter,
    child: EmptyState(
      icon: Icons.grid_view_rounded,
      title: AppContent.boardEmptyTitle,
      body: AppContent.boardEmptyBody,
      ghost: GhostKind.grid,
      height: 210,
    ),
  );
}
