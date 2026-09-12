import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/stats.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/habit_shade.dart';
import 'habit_detail_screen.dart';
import '../widgets/app_header.dart';
import '../widgets/tracking_guard.dart';
import '../widgets/day_strip.dart';
import '../widgets/habit_board.dart';
import '../widgets/day_status_dot.dart';
import '../widgets/illustrations.dart';
import '../widgets/empty_state.dart';
import '../widgets/k_card.dart';

/// Designed to fit one screen. Only the habit overview table scrolls, and only
/// when there are more habits than fit — the header, month grid and week
/// banner stay put.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onOpenDay});

  /// Opens [day] on Home — where a day is ticked, and where a habit that
  /// should have started back then is added.
  final void Function(DateTime day) onOpenDay;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with DayStripScroll {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final month = _month ?? DateTime(state.today.year, state.today.month);
    final pad = k.geometry.screenPadding;

    // Two views of the same history: the overview — the month and a week of
    // every habit, in detail — and the board, which is every habit across
    // weeks at a glance. The board lived on Home; it belongs here, with the
    // other ways of looking back.
    final board = state.calendarShowsBoard;

    // The month and the switch stay where they are; the white card under
    // them takes the rest of the height and scrolls inside itself. The whole
    // page scrolling carried the switch away with it, which made the board
    // feel like it was somewhere further down rather than right here.
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 6, pad, 0),
            child: Column(
              children: [
                const _CalendarTitle(),
                const SizedBox(height: 8),
                _MonthCard(
                  month: month,
                  onOpenDay: widget.onOpenDay,
                  onPrev: () => setState(
                    () => _month = DateTime(month.year, month.month - 1),
                  ),
                  onNext: () => setState(
                    () => _month = DateTime(month.year, month.month + 1),
                  ),
                  // Replaces the header icon that used to do this.
                  onToday: () => setState(
                    () =>
                        _month = DateTime(state.today.year, state.today.month),
                  ),
                ),
                const SizedBox(height: 12),
                // One section, two ways of looking at it: the week in detail,
                // or every habit across weeks at once. The switch sits where
                // the section's title was, so it is plainly about this part of
                // the page and not the month above it.
                _OverviewHeader(
                  board: board,
                  onSelect: (on) => state.setCalendarShowsBoard(on),
                  // The overview's days scroll; these step them a week at a
                  // time. The board carries its own pair.
                  canGoBack: earlier,
                  canGoForward: later,
                  onBack: () => stepWeek(back: true),
                  onForward: () => stepWeek(back: false),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
            child: board
                ? HabitBoard(
                    // The day comes from the block that was pressed, so the
                    // habit opens on that week rather than on this one.
                    onOpenDay: (habit, day) => HabitDetailScreen.open(
                      context,
                      habitId: habit.id,
                      day: day,
                    ),
                    // And the dates across the top open the whole day.
                    onOpenDate: widget.onOpenDay,
                  )
                : _OverviewTable(
                    head: stripHead,
                    body: stripBody,
                    fadeLeft: earlier,
                    fadeRight: later,
                    onCell: (width) => dayWidth = width,
                    onOpenDate: widget.onOpenDay,
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The switch between the two views
// ---------------------------------------------------------------------------

/// Overview or Board, drawn the same way as Home's Build / Cut back switch so
/// the two read as the same kind of control.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.board, required this.onSelect});

  final bool board;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        border: Border.all(color: k.colors.outline),
      ),
      child: Row(
        // As wide as its two labels, not the whole row: it shares the line
        // with the week's arrows.
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewTab(
            label: AppContent.calendarViewOverview,
            icon: Icons.calendar_view_month_outlined,
            selected: !board,
            onTap: () => onSelect(false),
          ),
          _ViewTab(
            label: AppContent.calendarViewBoard,
            icon: Icons.grid_view_rounded,
            selected: board,
            onTap: () => onSelect(true),
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ink = selected ? Colors.white : k.colors.textSecondary;

    return Material(
      color: selected ? k.colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(k.geometry.pillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: ink),
              const SizedBox(width: 5),
              Text(
                label,
                style: k.text.captionStrong.copyWith(
                  fontSize: 12.5,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title block
// ---------------------------------------------------------------------------

class _CalendarTitle extends StatelessWidget {
  const _CalendarTitle();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -k.geometry.screenPadding,
            right: -k.geometry.screenPadding,
            bottom: 0,
            child: const MountainScene(height: 64),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 2,
            child: ScreenHeader(
              title: AppContent.calendarTitle,
              subtitle: AppContent.calendarSubtitle,
              titleSize: 25,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month grid
// ---------------------------------------------------------------------------

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.onOpenDay,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;

  /// A date on the grid opens that day on Home.
  final void Function(DateTime day) onOpenDay;

  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();

    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // grid starts on Monday
    final cells = ((leading + daysInMonth) / 7).ceil() * 7;

    return KCard(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              _ArrowButton(icon: Icons.chevron_left, onTap: onPrev),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: k.text.sectionTitle.copyWith(fontSize: 15),
                ),
              ),
              // Space is reserved either way so the month title stays
              // centred whether or not the jump-to-today control shows.
              SizedBox(
                width: 26,
                child:
                    DateTime(month.year, month.month) ==
                        DateTime(state.today.year, state.today.month)
                    ? null
                    : InkWell(
                        onTap: onToday,
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(
                          Icons.today,
                          size: 17,
                          color: k.colors.accent,
                        ),
                      ),
              ),
              _ArrowButton(icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Three letters, not one: "M T W T F S S" is ambiguous.
              for (final label in const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: k.text.caption.copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          for (var row = 0; row < cells ~/ 7; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      day: first.add(Duration(days: row * 7 + col - leading)),
                      onTap: onOpenDay,
                      inMonth: () {
                        final index = row * 7 + col;
                        return index >= leading &&
                            index < leading + daysInMonth;
                      }(),
                      isToday:
                          first.add(Duration(days: row * 7 + col - leading)) ==
                          state.today,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          const _Legend(),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.onTap,
    required this.inMonth,
    required this.isToday,
  });

  final DateTime day;
  final void Function(DateTime day) onTap;
  final bool inMonth;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final status = inMonth ? state.dayStatus(day) : DayStatus.empty;

    return GestureDetector(
      // Opens that day's habits so a missed day can be filled in.
      onTap: inMonth ? () => onTap(day) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: k.colors.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: k.text.bodyStrong.copyWith(
                  fontSize: 12,
                  color: isToday
                      ? Colors.white
                      : inMonth
                      ? k.colors.textPrimary
                      : k.colors.textMuted,
                  fontWeight: inMonth ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Opacity(
              opacity: inMonth ? 1 : 0.35,
              child: DayStatusDot(status: status, size: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;

  /// Null when there is nothing that way: the arrow greys out rather than
  /// disappearing, so the pair keeps its shape.
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? k.colors.textMuted : k.colors.primary,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    Widget item(Widget dot, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 4),
        Text(label, style: k.text.caption.copyWith(fontSize: 9.5)),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 9,
      runSpacing: 3,
      children: [
        item(
          const DayStatusDot(status: DayStatus.all, size: 10),
          AppContent.calendarLegendAll,
        ),
        item(
          const DayStatusDot(status: DayStatus.some, size: 10),
          AppContent.calendarLegendSome,
        ),
        item(
          const DayStatusDot(status: DayStatus.none, size: 10),
          AppContent.calendarLegendNone,
        ),
        item(
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: k.colors.primary,
              shape: BoxShape.circle,
            ),
          ),
          AppContent.calendarLegendToday,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Habit overview
// ---------------------------------------------------------------------------

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.board,
    required this.onSelect,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  /// Which of the two views the section below is showing.
  final bool board;
  final ValueChanged<bool> onSelect;

  /// Whether the overview's strip has days that way, and how to go there.
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    // The arrows live out here rather than over the strip itself. Floating
    // them at its ends — where the board keeps its own — put them on top of
    // the Streak heading and a day's date, because the overview's columns are
    // half the board's width and it has a pinned column on both sides. This
    // line has the room, and it is where the week's arrows always were.
    return Row(
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _ViewSwitch(board: board, onSelect: onSelect),
          ),
        ),
        if (!board) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: k.colors.surface,
              borderRadius: BorderRadius.circular(k.geometry.pillRadius),
              border: Border.all(color: k.colors.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArrowButton(
                  icon: Icons.chevron_left,
                  tooltip: AppContent.boardEarlier,
                  onTap: canGoBack ? onBack : null,
                ),
                _ArrowButton(
                  icon: Icons.chevron_right,
                  tooltip: AppContent.boardLater,
                  onTap: canGoForward ? onForward : null,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The week-by-week table: habits down the left, days across, streak on the
/// right.
///
/// The days scroll sideways through ten weeks of history, the same run and the
/// same gesture as the board beside it. It used to sit on one week that you
/// stepped with a pair of arrows out in the section header, which made two
/// views of the same history behave like two different screens.
class _OverviewTable extends StatelessWidget {
  const _OverviewTable({
    required this.head,
    required this.body,
    required this.fadeLeft,
    required this.fadeRight,
    required this.onCell,
    required this.onOpenDate,
  });

  /// The dates, and the rows that drag them along. Both are the screen's, so
  /// the arrows up in the section header can step them.
  final ScrollController head;
  final ScrollController body;

  /// Which ends have more days beyond them.
  final bool fadeLeft;
  final bool fadeRight;

  /// One day's width, once the strip has been measured.
  final ValueChanged<double> onCell;

  /// Tapping a date opens that whole day.
  final void Function(DateTime day) onOpenDate;

  /// The pinned columns either side of the days, and the height of a row.
  static const double _names = 100;
  static const double _streak = 36;
  static const double _day = 24;
  static const double _row = 30;
  static const double _header = 30;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final today = state.today;
    final days = [
      for (var i = HabitBoard.days - 1; i >= 0; i--)
        today.subtract(Duration(days: i)),
    ];

    // Includes habits discontinued inside the window, so the days they were
    // running do not silently disappear from the record.
    final habits = state.habitsInRange(days.first, days.last);

    // Nothing to put in the table: a preview of it instead of its headings.
    if (habits.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: EmptyState(
          icon: Icons.view_list_rounded,
          title: AppContent.overviewEmptyTitle,
          body: AppContent.overviewEmptyBody,
          height: 190,
        ),
      );
    }

    Widget label(String text, {required double width, bool right = false}) =>
        SizedBox(
          width: width,
          child: Text(
            text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: k.text.caption.copyWith(fontSize: 9.5),
          ),
        );

    // Held to the top and as tall as its rows, like the board beside it.
    return Align(
      alignment: Alignment.topCenter,
      child: KCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: LayoutBuilder(
          builder: (context, box) {
            // Whole days only: the strip is what is left after the two pinned
            // columns, and at the nominal width its edge cut one in half.
            final strip = box.maxWidth - _names - _streak;
            final cell = strip / math.max(1, (strip / _day).floor());
            onCell(cell);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The dates, pinned above and dragged along by the rows.
                Row(
                  children: [
                    label(AppContent.calendarHabitColumn, width: _names),
                    Expanded(
                      child: SizedBox(
                        height: _header,
                        child: SingleChildScrollView(
                          controller: head,
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: [
                              for (final day in days)
                                _OverviewDate(
                                  day: day,
                                  isToday: day == today,
                                  width: cell,
                                  onTap: () => onOpenDate(day),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    label(
                      AppContent.calendarStreakLabel,
                      width: _streak,
                      right: true,
                    ),
                  ],
                ),
                // The rows scroll under the dates, and their days scroll
                // between the names and the streaks.
                Flexible(
                  child: SingleChildScrollView(
                    child: CustomPaint(
                      // The rules under the rows, drawn in one piece across
                      // all three columns: as a border on each cell they came
                      // out in segments, because the strip's edges fade and
                      // took their share of the line with them.
                      foregroundPainter: _RowLines(
                        rows: habits.length,
                        height: _row,
                        colour: k.colors.outline,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _names,
                            child: Column(
                              children: [
                                for (final habit in habits)
                                  _OverviewName(habit: habit, height: _row),
                              ],
                            ),
                          ),
                          Expanded(
                            child: EdgeFade(
                              left: fadeLeft,
                              right: fadeRight,
                              child: ScrollConfiguration(
                                // The bar would lie across the bottom row, and
                                // this scrolls by dragging anyway.
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(scrollbars: false),
                                child: SingleChildScrollView(
                                  controller: body,
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: Column(
                                    children: [
                                      for (final habit in habits)
                                        _OverviewDays(
                                          habit: habit,
                                          days: days,
                                          width: cell,
                                          height: _row,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _streak,
                            child: Column(
                              children: [
                                for (final habit in habits)
                                  _OverviewStreak(habit: habit, height: _row),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One date over its column, with today ringed. The overview's own, smaller
/// than the board's because its days are half the width.
class _OverviewDate extends StatelessWidget {
  const _OverviewDate({
    required this.day,
    required this.isToday,
    required this.width,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(day).substring(0, 1),
              style: k.text.caption.copyWith(fontSize: 8.5),
            ),
            const SizedBox(height: 1),
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: k.colors.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: k.text.captionStrong.copyWith(
                  fontSize: 9,
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

/// The row's habit, in the column that does not scroll.
class _OverviewName extends StatelessWidget {
  const _OverviewName({required this.habit, required this.height});

  final Habit habit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final accent = k.colors.accentFor(habit.iconKey);
    final stopped = habit.isArchived;

    return _RowCell(
      height: height,
      child: Opacity(
        opacity: stopped ? 0.6 : 1,
        child: Row(
          children: [
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: accent.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.forKey(habit.iconKey),
                size: 11,
                color: accent.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                habit.name,
                style: k.text.bodyStrong.copyWith(
                  fontSize: 10.5,
                  color: stopped ? k.colors.textMuted : k.colors.textPrimary,
                  decoration: stopped ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The row's days, in the part that scrolls.
class _OverviewDays extends StatelessWidget {
  const _OverviewDays({
    required this.habit,
    required this.days,
    required this.width,
    required this.height,
  });

  final Habit habit;
  final List<DateTime> days;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return _RowCell(
      height: height,
      padded: false,
      child: Opacity(
        opacity: habit.isArchived ? 0.6 : 1,
        child: Row(
          children: [
            for (final day in days)
              SizedBox(
                width: width,
                child: Center(
                  child: _DayMark(
                    habit: habit,
                    day: day,
                    colour: state.colorFor(habit),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The row's streak, in the column that does not scroll.
class _OverviewStreak extends StatelessWidget {
  const _OverviewStreak({required this.habit, required this.height});

  final Habit habit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final streak = context.watch<AppState>().habitStreak(habit);

    return _RowCell(
      height: height,
      child: Opacity(
        opacity: habit.isArchived ? 0.6 : 1,
        // Long streaks ("124 d") must not overflow the fixed column.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 11,
                color: k.colors.flame,
              ),
              const SizedBox(width: 2),
              Text(
                '$streak d',
                style: k.text.captionStrong.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row's worth of one column, held to the same height in all three, so a
/// row lines up across the table even though the middle of it is on a strip
/// that has been scrolled somewhere else.
class _RowCell extends StatelessWidget {
  const _RowCell({
    required this.height,
    required this.child,
    this.padded = true,
  });

  final double height;
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: padded ? const EdgeInsets.symmetric(vertical: 5) : null,
      child: child,
    );
  }
}

/// The rules between the rows, across the whole table.
class _RowLines extends CustomPainter {
  const _RowLines({
    required this.rows,
    required this.height,
    required this.colour,
  });

  final int rows;
  final double height;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..color = colour
      ..strokeWidth = 1;
    // Between the rows, and not under the last one: a line along the bottom
    // of the card reads as the table being cut off there.
    for (var i = 1; i < rows; i++) {
      final y = height * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brush);
    }
  }

  @override
  bool shouldRepaint(_RowLines old) =>
      old.rows != rows || old.height != height || old.colour != colour;
}

/// A single habit/day intersection in the overview grid.
class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.habit,
    required this.day,
    required this.colour,
  });

  final Habit habit;
  final DateTime day;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final d = dateOnly(day);
    final shown = habit.isActiveOnDay(d) && !d.isAfter(state.today);
    final fraction = doneFraction(habit, state.valueOf(habit.id, d));

    // The habit's own colour at the depth the day earned — the board's
    // language, so a row here and a band there are recognisably the same
    // habit. A tick on a solid green disc said only "done", and said it in
    // the same green for every habit on the page.
    // Before the habit started — or after it was discontinued — there was
    // nothing to do, and an empty ring said there was and you did not do it.
    // A dot the size of a full stop: the column keeps its rhythm, and where
    // the rings begin is where the habit begins.
    final Widget mark = !shown
        ? _untracked(k)
        : fraction == 0
        ? _empty(k)
        : Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: habitShade(colour, fraction),
              shape: BoxShape.circle,
            ),
          );

    if (!shown) {
      // Says what the gap is, since there is nothing else on this screen that
      // could. Future days are not on the strip, so this is always the past.
      return GestureDetector(
        onTap: () => showUntrackedNote(context, habit, d),
        behavior: HitTestBehavior.opaque,
        child: Padding(padding: const EdgeInsets.all(3), child: mark),
      );
    }

    // Opens the habit on that day rather than ticking it.
    //
    // A tap here used to call toggleComplete, which on anything with a target
    // either threw a part-done day away or filled it in. This screen shows
    // seven days across eight habits at fourteen pixels each; it is a place to
    // read from, and the one place to change a day is the habit's own screen.
    return GestureDetector(
      onTap: () => HabitDetailScreen.open(context, habitId: habit.id, day: d),
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.all(3), child: mark),
    );
  }

  Widget _untracked(RewireMindTheme k) => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: k.colors.accentTrack.withValues(alpha: 0.7),
    ),
  );

  Widget _empty(RewireMindTheme k) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: k.colors.accentTrack, width: 1.3),
    ),
  );
}

// ---------------------------------------------------------------------------
// Week banner
// ---------------------------------------------------------------------------
