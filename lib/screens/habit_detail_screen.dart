import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/habit.dart';
import '../widgets/app_snackbar.dart';
import '../models/habit_note.dart';
import '../models/habit_log.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/habit_shade.dart';
import '../widgets/app_background.dart';
import '../widgets/habit_row.dart';
import '../widgets/k_card.dart';
import '../widgets/tracking_guard.dart';
import '../content/notification_content.dart';
import '../content/reminder_library.dart';
import '../models/reminder.dart';
import 'habit_actions_sheet.dart';
import 'habit_editor_sheet.dart';
import 'notifications_screen.dart';
import 'reminder_editor_sheet.dart';
import '../widgets/challenge_guard.dart';

/// Everything about one habit: one day's progress, its streaks, and its
/// history.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId, this.day});

  final String habitId;

  /// The day the screen opens on, and the week its history grid ends with.
  /// Defaults to today. Whoever opened this decides — the board passes the day
  /// whose block was pressed.
  final DateTime? day;

  static Future<void> open(
    BuildContext context, {
    required String habitId,
    DateTime? day,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habitId: habitId, day: day),
      ),
    );
  }

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  /// The day the card at the top edits, moved by tapping the history grid.
  /// Null until the first build, when today is known.
  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;

    // The habit can vanish while this screen is open (delete), so look it up
    // defensively rather than holding a stale copy.
    final habit = state.allHabits
        .where((h) => h.id == widget.habitId)
        .firstOrNull;
    if (habit == null) {
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _bar(context, null),
          body: const SizedBox.shrink(),
        ),
      );
    }

    final target =
        _picked ?? (widget.day == null ? state.today : dateOnly(widget.day!));

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _bar(context, habit),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            k.geometry.screenPadding,
            4,
            k.geometry.screenPadding,
            28,
          ),
          children: [
            _HabitSummary(habit: habit),
            const SizedBox(height: 11),
            _TodayCard(habit: habit, day: target),
            const SizedBox(height: 11),
            _StatsRow(habit: habit),
            const SizedBox(height: 11),
            _HistoryCard(
              habit: habit,
              selected: target,
              // The week the grid is drawn around stays where the screen was
              // opened, so tapping a day in its first row moves the card and
              // not the grid out from under your finger.
              anchor: widget.day == null ? state.today : dateOnly(widget.day!),
              onPick: (day) => setState(() => _picked = day),
            ),
            const SizedBox(height: 11),
            _RemindersCard(habit: habit),
            const SizedBox(height: 11),
            _NotesCard(habit: habit, day: target),
            const SizedBox(height: 18),
            _LifecycleButton(habit: habit),
            const SizedBox(height: 10),
            _DeleteButton(habit: habit),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _bar(BuildContext context, Habit? habit) {
    final k = context.k;
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: k.colors.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      // Deliberately blank. The card below opens with the habit's name at a
      // size worth reading; the same name in the bar directly above it was the
      // word twice on two consecutive lines. The bar keeps its two controls.
      title: const SizedBox.shrink(),
      actions: [
        if (habit != null)
          IconButton(
            icon: Icon(Icons.edit_outlined, color: k.colors.primary, size: 20),
            onPressed: () => HabitEditorSheet.show(context, habit: habit),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _HabitSummary extends StatelessWidget {
  const _HabitSummary({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KCard(
      child: Row(
        children: [
          IconChip(
            iconKey: habit.iconKey,
            icon: AppIcons.forKey(habit.iconKey),
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The name, and at the size a title deserves.
                //
                // This card used to lead with "8 hours per day" and leave the
                // habit's own name to the app bar at 17pt — so the biggest
                // words on a screen about one habit were about its target.
                // The goal, the days and the start date are all worth having;
                // none of them is what the screen is called.
                Text(
                  habit.name,
                  style: k.text.sectionTitle.copyWith(fontSize: 20),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppContent.targetSummary(_trim(habit.target), habit.unit)}'
                  ' · ${_scheduleLabel(habit)}',
                  style: k.text.caption.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppContent.detailSince} '
                  '${DateFormat('d MMM yyyy').format(habit.createdAt)}',
                  style: k.text.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _trim(double n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();

  /// "Every day" or "Mon, Wed, Fri".
  static String _scheduleLabel(Habit habit) {
    if (habit.activeWeekdays.length == 7) {
      return AppContent.detailScheduleEveryDay;
    }
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = habit.activeWeekdays.toList()..sort();
    return days.map((d) => names[d - 1]).join(', ');
  }
}

// ---------------------------------------------------------------------------

/// Today's progress, with a stepper for habits measured in units.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.habit, required this.day});

  final Habit habit;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final value = state.valueOf(habit.id, day);
    final complete = state.isComplete(habit, day);
    final isToday = day == state.today;
    final isFuture = day.isAfter(state.today);
    final step = habit.step;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday
                          ? AppContent.detailTodayTitle
                          : DateFormat('EEEE, d MMMM').format(day),
                      style: k.text.sectionTitle.copyWith(fontSize: 15),
                    ),
                    Text(
                      isFuture
                          ? AppContent.daySheetFuture
                          : habit.progressLabel(value),
                      style: k.text.caption.copyWith(
                        color: complete
                            ? k.colors.accent
                            : k.colors.textSecondary,
                        fontWeight: complete
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              CheckButton(
                complete: complete,
                enabled: !isFuture,
                onTap: () => editTrackedDay(
                  context,
                  habit,
                  day,
                  () => editChallengeDay(
                    context,
                    day,
                    () => context.read<AppState>().toggleComplete(habit, day),
                  ),
                ),
                size: 34,
              ),
            ],
          ),
          if (!habit.isBinary) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove,
                  onTap: value <= 0 || isFuture
                      ? null
                      : () => editTrackedDay(
                          context,
                          habit,
                          day,
                          () => editChallengeDay(
                            context,
                            day,
                            () => context.read<AppState>().adjustValue(
                              habit,
                              day,
                              -step,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 9,
                      child: LinearProgressIndicator(
                        value: habit.target == 0
                            ? 0
                            : (value / habit.target).clamp(0.0, 1.0),
                        backgroundColor: k.colors.accentTrack,
                        valueColor: AlwaysStoppedAnimation(k.colors.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _StepButton(
                  icon: Icons.add,
                  onTap: value >= habit.target || isFuture
                      ? null
                      : () => editTrackedDay(
                          context,
                          habit,
                          day,
                          () => editChallengeDay(
                            context,
                            day,
                            () => context.read<AppState>().adjustValue(
                              habit,
                              day,
                              step,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final enabled = onTap != null;
    return Material(
      color: enabled ? k.colors.primarySoft : k.colors.surfaceSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 19,
            color: enabled ? k.colors.primary : k.colors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final percent = state.habitDonePercent(habit);

    Widget stat(
      IconData icon,
      Color tint,
      String value,
      String label,
    ) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: k.text.statValue.copyWith(fontSize: 15)),
                  const SizedBox(width: 3),
                  Text(label, style: k.text.caption.copyWith(fontSize: 10.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    Widget divider() =>
        Container(width: 1, height: 16, color: k.colors.outline);

    return KCard(
      soft: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Row(
        children: [
          stat(
            Icons.local_fire_department,
            k.colors.flame,
            '${state.habitStreak(habit)}',
            AppContent.detailStreakShort,
          ),
          divider(),
          stat(
            Icons.star,
            k.colors.star,
            '${state.habitBestStreak(habit)}',
            AppContent.detailBestShort,
          ),
          divider(),
          stat(
            Icons.donut_large,
            k.colors.accent,
            '$percent%',
            AppContent.detailCompletionShort,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Eight-week grid of this habit's completions.
/// How much of a habit's past to show at once.
enum HistorySpan {
  week(1, AppContent.historySpanWeek),
  month(4, AppContent.historySpanMonth),
  all(0, AppContent.historySpanAll);

  const HistorySpan(this.weeks, this.label);

  /// Whole weeks to draw. Zero means "as many as the habit has existed for".
  final int weeks;
  final String label;
}

/// One habit's history, in its own colour, at the depth each day earned.
///
/// A week by default rather than six: seven blocks across a phone are wide
/// enough to carry the date inside them, which is what the old grid could not
/// do — it labelled its columns M T W T F S S and left you to work out which
/// M. Wider spans trade that date away for reach, which is the right trade at
/// four weeks and the only possible one at all time.
class _HistoryCard extends StatefulWidget {
  const _HistoryCard({
    required this.habit,
    required this.selected,
    required this.anchor,
    required this.onPick,
  });

  final Habit habit;

  /// The day the card above is editing, ringed in the grid.
  final DateTime selected;

  /// The day whose week is the grid's last row. Held still while [selected]
  /// moves, so picking a day does not scroll the grid away from it.
  final DateTime anchor;

  /// Moves the card above to a day.
  final ValueChanged<DateTime> onPick;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  HistorySpan _span = HistorySpan.week;

  /// Room for "Sep" beside the weeks, on the spans that have no room for a
  /// date inside the blocks themselves.
  static const double _monthGutter = 26;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final lastMonday = startOfWeek(widget.anchor);
    final colour = state.colorFor(widget.habit);

    // All time runs from the week the habit was created to the week on screen,
    // capped so a habit somebody has kept for two years does not try to draw
    // a hundred rows into a card.
    final firstMonday = startOfWeek(dateOnly(widget.habit.createdAt));
    final lived = lastMonday.difference(firstMonday).inDays ~/ 7 + 1;
    final weeks = _span.weeks == 0 ? lived.clamp(1, 26) : _span.weeks;

    final from = lastMonday.subtract(Duration(days: (weeks - 1) * 7));
    final to = lastMonday.add(const Duration(days: 6));

    // One row of seven is wide enough for a date in every block; four rows
    // still are, just. Past that the numbers stop being legible, so they go.
    final rowHeight = weeks == 1 ? 46.0 : (weeks <= 4 ? 34.0 : 20.0);
    final showDates = weeks <= 4;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppContent.detailHistoryTitle,
                      style: k.text.sectionTitle.copyWith(fontSize: 15),
                    ),
                    // Always the actual dates, so the grid can never be
                    // ambiguous about which fortnight it is drawing.
                    Text(
                      AppContent.historyRange(
                        DateFormat('d MMM').format(from),
                        DateFormat('d MMM yyyy').format(to),
                      ),
                      style: k.text.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              _SpanPicker(
                selected: _span,
                onSelect: (span) => setState(() => _span = span),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // The gutter the month names go in, held open here as well so
              // the weekday letters stay over their own columns.
              if (!showDates) const SizedBox(width: _monthGutter),
              for (final label in AppContent.weekdayInitials)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: k.text.caption.copyWith(fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Blocks that touch, like the board's. The rounded corners belong to
          // the whole field rather than to each day in it — a grid of separate
          // chips is something you count, and a field of colour is something
          // you take in.
          ClipRRect(
            borderRadius: BorderRadius.circular(k.geometry.innerRadius),
            child: Column(
              children: [
                for (var w = weeks - 1; w >= 0; w--)
                  () {
                    final monday = lastMonday.subtract(Duration(days: w * 7));
                    // Over a long span the dates come off the blocks — the
                    // digits are illegible at that size — which left a field
                    // of colour with nothing to locate it by. A month name
                    // against the week it starts in puts that back, and costs
                    // one label per month rather than one per day.
                    final older = monday.subtract(const Duration(days: 7));
                    final startsMonth = monday.month != older.month;

                    return SizedBox(
                      height: rowHeight,
                      child: Row(
                        children: [
                          if (!showDates)
                            SizedBox(
                              width: _monthGutter,
                              child: startsMonth
                                  ? Text(
                                      DateFormat('MMM').format(monday),
                                      style: k.text.captionStrong.copyWith(
                                        fontSize: 9.5,
                                        color: k.colors.textMuted,
                                      ),
                                    )
                                  : null,
                            ),
                          for (var d = 0; d < 7; d++)
                            Expanded(
                              child: _HistoryCell(
                                habit: widget.habit,
                                day: monday.add(Duration(days: d)),
                                today: state.today,
                                selected: widget.selected,
                                colour: colour,
                                showDate: showDates,
                                onPick: widget.onPick,
                              ),
                            ),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppContent.detailHistorySubtitle,
                  style: k.text.caption.copyWith(fontSize: 10.5),
                ),
              ),
              Container(
                width: 52,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [habitShade(colour, 0), habitShade(colour, 1)],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The span picker: the Progress screen's control, at a card's scale.
class _SpanPicker extends StatelessWidget {
  const _SpanPicker({required this.selected, required this.onSelect});

  final HistorySpan selected;
  final ValueChanged<HistorySpan> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return PopupMenuButton<HistorySpan>(
      initialValue: selected,
      onSelected: onSelect,
      position: PopupMenuPosition.under,
      color: k.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      ),
      itemBuilder: (context) => [
        for (final span in HistorySpan.values)
          PopupMenuItem<HistorySpan>(
            value: span,
            height: 40,
            child: Row(
              children: [
                Icon(
                  span == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: span == selected
                      ? k.colors.primary
                      : k.colors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  span.label,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 12,
                    color: span == selected
                        ? k.colors.primary
                        : k.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 6, 7, 6),
        decoration: BoxDecoration(
          color: k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(k.geometry.pillRadius),
          border: Border.all(color: k.colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: k.text.captionStrong.copyWith(
                fontSize: 11.5,
                color: k.colors.primary,
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 16,
              color: k.colors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day of one habit: a slice of the band.
class _HistoryCell extends StatelessWidget {
  const _HistoryCell({
    required this.habit,
    required this.day,
    required this.today,
    required this.selected,
    required this.colour,
    required this.showDate,
    required this.onPick,
  });

  final Habit habit;
  final DateTime day;
  final DateTime today;
  final DateTime selected;
  final Color colour;

  /// Moves the card above to this day.
  final ValueChanged<DateTime> onPick;

  /// Whether there is room to print the day of the month in the block. There
  /// is at one and four weeks; past that the digits stop being legible and a
  /// grid of grey specks is worse than none.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;

    final outOfRange = day.isAfter(today) || !habit.isActiveOnDay(day);
    final fraction = doneFraction(habit, state.valueOf(habit.id, day));

    // Nothing done, and days that were never asked for, are drawn as the bare
    // track rather than as a pale version of the colour. On a field where
    // every filled block means "some of this got done", a blank is the
    // clearest way to say none of it did.
    final Color fill;
    if (outOfRange) {
      fill = k.colors.accentTrack.withValues(alpha: 0.30);
    } else if (fraction == 0) {
      fill = k.colors.accentTrack.withValues(alpha: 0.55);
    } else {
      fill = habitShade(colour, fraction);
    }

    final picked = day == selected;
    final isToday = day == today;

    // Ink that works at both ends of the ramp: dark on a filled block, muted
    // on an empty one. The digit and the dot both need it.
    final deep = fraction > 0.55;

    return GestureDetector(
      // Days that have not happened yet, and days before the habit began,
      // have nothing to log, so they do not move the card.
      onTap: outOfRange ? null : () => onPick(day),
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: DateFormat('EEE d MMM').format(day),
        // Tapping a day moves the card above to it. It never changes the day
        // itself — this grid used to tick a day when tapped, which on a habit
        // with a target had to guess whether six of ten meant finished or
        // abandoned. It picks; the card above is where you log.
        //
        // Filling the row rather than sizing to whatever is inside it. A block
        // with a date in it used to be as tall as the date and a block without
        // one filled its row, so the same grid drew thin bars at one week and
        // solid bands at all time — and today, carrying a dot as well as a
        // digit, grew taller than its neighbours.
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              // The ring belongs to the day the card above is editing, and to
              // nothing else. It used to be shared with today at a lower opacity,
              // which put two green marks on the grid that differed by an alpha
              // value — not a difference anybody reads.
              border: picked
                  ? Border.all(color: k.colors.primary, width: 2)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showDate)
                  Text(
                    '${day.day}',
                    style: k.text.caption.copyWith(
                      fontSize: 10,
                      fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
                      color: deep
                          ? Colors.black.withValues(alpha: 0.55)
                          : k.colors.textMuted,
                    ),
                  ),
                // Today, as a dot rather than a second ring. A different shape
                // saying a different thing: not "this is the one" but "you are
                // here". On the day that is both, the block gets both, which is
                // the honest reading.
                if (isToday)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: deep
                            ? Colors.white.withValues(alpha: 0.9)
                            : k.colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Stop tracking (or resume) — the safe counterpart to deleting.
///
/// Discontinuing keeps the habit's history, so past percentages and streaks
/// stay true to what actually happened.
class _LifecycleButton extends StatelessWidget {
  const _LifecycleButton({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final stopped = habit.isArchived;

    return Material(
      color: stopped ? k.colors.primarySoft : k.colors.surfaceSoft,
      borderRadius: BorderRadius.circular(k.geometry.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        onTap: () => stopped
            ? context.read<AppState>().restoreHabit(habit)
            : _confirmStop(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                stopped ? Icons.play_arrow : Icons.pause_circle_outline,
                size: 19,
                color: k.colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                stopped
                    ? AppContent.detailResume
                    : AppContent.detailDiscontinue,
                style: k.text.cardTitle.copyWith(color: k.colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStop(BuildContext context) async {
    final k = context.k;
    final state = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(
          AppContent.detailDiscontinueTitle,
          style: k.text.sectionTitle.copyWith(fontSize: 17),
        ),
        content: Text(AppContent.detailDiscontinueBody, style: k.text.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppContent.editorCancel,
              style: k.text.bodyStrong.copyWith(color: k.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppContent.detailDiscontinueConfirm,
              style: k.text.bodyStrong.copyWith(color: k.colors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await state.archiveHabit(habit);
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: k.colors.dangerSoft,
      borderRadius: BorderRadius.circular(k.geometry.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        onTap: () => _confirm(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, size: 19, color: k.colors.danger),
              const SizedBox(width: 8),
              Text(
                AppContent.detailDelete,
                style: k.text.cardTitle.copyWith(color: k.colors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final k = context.k;
    final navigator = Navigator.of(context);
    final state = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(
          AppContent.detailDeleteTitle,
          style: k.text.sectionTitle.copyWith(fontSize: 17),
        ),
        content: Text(AppContent.detailDeleteBody, style: k.text.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppContent.editorCancel,
              style: k.text.bodyStrong.copyWith(color: k.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppContent.detailDeleteConfirm,
              style: k.text.bodyStrong.copyWith(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await state.deleteHabit(habit);
      navigator.pop();
    }
  }
}

// ---------------------------------------------------------------------------

/// Reminders for this habit alone.
///
/// Scoped rather than global: `{habit}` resolves to this habit, and "skip once
/// ticked" watches this habit rather than the whole day.
class _RemindersCard extends StatelessWidget {
  const _RemindersCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final reminders = state.notifyPrefs.forHabit(habit.id);
    final notificationsOn = state.notifyPrefs.enabled;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_none,
                size: 18,
                color: k.colors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                NotificationContent.habitRemindersTitle,
                style: k.text.cardTitle,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(NotificationContent.habitRemindersBlurb, style: k.text.caption),
          if (!notificationsOn) ...[
            // A sentence telling somebody where the switch is, on a card with
            // no way of getting there, is a dead end with instructions on it.
            // The row goes.
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => NotificationsScreen.open(context),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(
                  NotificationContent.habitRemindersOff,
                  style: k.text.captionStrong.copyWith(color: k.colors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: k.colors.primary,
                  side: BorderSide(color: k.colors.outline),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(k.geometry.chipRadius),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            if (reminders.isEmpty)
              Text(
                NotificationContent.habitRemindersEmpty,
                style: k.text.caption.copyWith(color: k.colors.textMuted),
              )
            else
              for (final reminder in reminders)
                _HabitReminderRow(reminder: reminder),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _HabitPresetPicker.show(context, habitId: habit.id),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  NotificationContent.addLabel,
                  style: k.text.captionStrong.copyWith(color: k.colors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: k.colors.primary,
                  side: BorderSide(color: k.colors.outline),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(k.geometry.chipRadius),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HabitReminderRow extends StatelessWidget {
  const _HabitReminderRow({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.read<AppState>();
    final dimmed = !reminder.enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ReminderEditorSheet.show(context, reminder: reminder),
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  reminder.time.format(),
                  style: k.text.captionStrong.copyWith(
                    fontSize: 13.5,
                    color: dimmed ? k.colors.textMuted : k.colors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.text,
                      style: k.text.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: dimmed ? k.colors.textMuted : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      reminder.scheduleLabel,
                      style: k.text.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: reminder.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: k.colors.accent,
                onChanged: (on) =>
                    state.saveReminder(reminder.copyWith(enabled: on)),
              ),
              DeleteReminderButton(reminder: reminder),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wording for a habit reminder, shown with this habit's own name filled in.
class _HabitPresetPicker extends StatelessWidget {
  const _HabitPresetPicker({required this.habitId, required this.habitName});

  final String habitId;
  final String habitName;

  static Future<void> show(BuildContext context, {required String habitId}) {
    final state = context.read<AppState>();
    final habit = state.allHabits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return Future.value();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _HabitPresetPicker(habitId: habitId, habitName: habit.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: k.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: k.colors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                children: [
                  Text(
                    NotificationContent.presetsTitle,
                    style: k.text.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ReminderEditorSheet.show(context, habitId: habitId);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(
                        NotificationContent.customLabel,
                        style: k.text.captionStrong.copyWith(
                          color: k.colors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: k.colors.primary,
                        side: BorderSide(color: k.colors.outline),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            k.geometry.chipRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final preset in ReminderLibrary.habitPresets)
                    () {
                      // Resolved here, before the wording ever reaches the
                      // editor — so the user picks, and later edits, a plain
                      // sentence with their habit's real name in it.
                      final resolved = ReminderPreset(
                        NotificationContent.forHabit(preset.text, habitName),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: k.colors.surfaceSoft,
                          borderRadius: BorderRadius.circular(
                            k.geometry.innerRadius,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              k.geometry.innerRadius,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              ReminderEditorSheet.show(
                                context,
                                preset: resolved,
                                habitId: habitId,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                13,
                                10,
                                13,
                                10,
                              ),
                              child: Text(
                                resolved.text,
                                style: k.text.captionStrong,
                              ),
                            ),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Everything the user has written about this habit, newest first.
///
/// Notes were write-only until now: you could record "skipped, calf sore" and
/// never see it again. They are the only place in the app that holds the
/// user's own words, which makes them the last thing that should be invisible.
class _NotesCard extends StatefulWidget {
  const _NotesCard({required this.habit, required this.day});

  final Habit habit;

  /// The day the screen is on — where "Add note" writes.
  final DateTime day;

  @override
  State<_NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<_NotesCard> {
  /// The detail screen is meant to sit on one page, so a long history folds
  /// away rather than pushing everything else off the bottom.
  static const int _collapsed = 3;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final notes = state.notesFor(widget.habit.id);
    final shown = _showAll ? notes : notes.take(_collapsed).toList();

    return KCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 17,
                color: k.colors.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  AppContent.detailNotesTitle,
                  style: k.text.sectionTitle.copyWith(fontSize: 15),
                ),
              ),
              // Writing one was only possible by long-pressing the row on
              // Home, which is not a thing anybody finds.
              TextButton.icon(
                onPressed: () => HabitNoteSheet.show(
                  context,
                  habit: widget.habit,
                  day: widget.day,
                ),
                // Not a bare plus: the stepper on this same screen already
                // owns that, and "add a note" is a different verb anyway.
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: Text(
                  AppContent.detailNotesAdd,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 12,
                    color: k.colors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: k.colors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          Text(
            notes.isEmpty
                ? AppContent.detailNotesEmpty
                : AppContent.detailNotesSubtitle,
            style: k.text.caption.copyWith(fontSize: 10.5),
          ),
          if (notes.isNotEmpty) const SizedBox(height: 8),
          for (final note in shown) _NoteRow(habit: widget.habit, note: note),
          if (notes.length > _collapsed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                style: TextButton.styleFrom(
                  foregroundColor: k.colors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _showAll
                      ? AppContent.detailNotesShowFewer
                      : AppContent.detailNotesShowAll(notes.length),
                  style: k.text.captionStrong.copyWith(
                    fontSize: 12,
                    color: k.colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.habit, required this.note});

  final Habit habit;
  final HabitNote note;

  DateTime get day => note.day;
  String get text => note.text;

  /// Deletes it straight away, with an Undo — the same pattern reminders use.
  /// A confirmation dialog for a line of text is a question nobody needs.
  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    final removed = await state.deleteNote(habit, note.day, note.index);
    if (removed == null || !context.mounted) return;
    await showAppSnackBar(
      context,
      message: AppContent.detailNoteDeleted,
      actionLabel: AppContent.detailMarkUndone,
      onAction: () => state.restoreNote(habit, note.day, note.index, removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final done = state.isComplete(habit, day);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        onTap: () => HabitNoteSheet.show(
          context,
          habit: habit,
          day: day,
          index: note.index,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A thin rule in the day's own colour, so the history reads as
              // "kept it / did not" at a glance without a second label.
              Container(
                width: 3,
                height: 30,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  color: done ? k.colors.accent : k.colors.accentTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE d MMM').format(day),
                      style: k.text.caption.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: k.colors.textMuted,
                      ),
                    ),
                    Text(
                      text,
                      style: k.text.body.copyWith(fontSize: 12.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppContent.detailNoteDelete,
                onPressed: () => _delete(context),
                icon: Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: k.colors.textMuted,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
