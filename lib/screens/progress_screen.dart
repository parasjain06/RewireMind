import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/progress_range.dart';
import '../models/stats.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/habit_shade.dart';
import '../widgets/app_header.dart';
import '../widgets/illustrations.dart';
import '../widgets/empty_state.dart';
import '../widgets/k_card.dart';
import '../widgets/progress_charts.dart';
import '../widgets/script_note.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  /// Honours `?range=month|year|allTime` for development on web, matching the
  /// `?tab=` hook in HomeShell; ignored elsewhere.
  ProgressRange _range = ProgressRange.values.firstWhere(
    (r) => r.name == Uri.base.queryParameters['range'],
    orElse: () => ProgressRange.week,
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final copy = AppContent.progressFor(_range);
    final stats = state.statsFor(_range);

    // The range sits in the header rather than in a row of its own: it scopes
    // the whole page — tiles, chart and breakdown — so it has to read as a
    // page-level control, and a full row of pills for something changed
    // occasionally was a lot of screen.
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              6,
              k.geometry.screenPadding,
              0,
            ),
            child: _ProgressTitle(
              copy: copy,
              selected: _range,
              onSelect: (r) => setState(() => _range = r),
            ),
          ),
        ),
        // Everything above the breakdown is a fixed size, so the page as a
        // whole no longer scrolls. Only the habit list inside the breakdown
        // does, and only once there are more habits than fit.
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              10,
              k.geometry.screenPadding,
              12,
            ),
            child: Column(
              children: [
                _StatTiles(range: _range, stats: stats, copy: copy),
                const SizedBox(height: 11),
                _ChartCard(range: _range, stats: stats, copy: copy),
                const SizedBox(height: 11),
                // Flexible rather than Expanded: with two habits the card
                // should be two rows tall, not a tall box with a short list
                // rattling around at the top of it. It only grows to fill the
                // page when there are enough habits to need it.
                Flexible(
                  child: _BreakdownCard(
                    range: _range,
                    stats: stats,
                    copy: copy,
                  ),
                ),
                // Pinned under the list, in the same slim shape the Calendar
                // banner uses. Because it is a fixed child, the breakdown
                // simply starts scrolling sooner rather than the page
                // overflowing — which is what the taller version used to do.
                // Not while there is nothing to count: the empty chart and
                // breakdown above already say so.
                if (stats.scheduled > 0) ...[
                  const SizedBox(height: 10),
                  _ProgressBanner(stats: stats, copy: copy),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ProgressTitle extends StatelessWidget {
  const _ProgressTitle({
    required this.copy,
    required this.selected,
    required this.onSelect,
  });

  final ProgressCopy copy;
  final ProgressRange selected;
  final ValueChanged<ProgressRange> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -k.geometry.screenPadding,
            right: -k.geometry.screenPadding,
            bottom: 0,
            child: const MountainScene(height: 74),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ScreenHeader(
                    title: AppContent.progressTitle,
                    subtitle: copy.subtitle,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _RangeDropdown(selected: selected, onSelect: onSelect),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Period selector, as a compact menu.
///
/// A row of four pills was a tap faster, but took a whole row for a control
/// that is changed occasionally. This keeps it one line in the header, where
/// it also reads as scoping the page rather than the chart it sits above.
class _RangeDropdown extends StatelessWidget {
  const _RangeDropdown({required this.selected, required this.onSelect});

  final ProgressRange selected;
  final ValueChanged<ProgressRange> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return PopupMenuButton<ProgressRange>(
      initialValue: selected,
      onSelected: onSelect,
      tooltip: AppContent.progressRangeTooltip,
      position: PopupMenuPosition.under,
      color: k.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      ),
      itemBuilder: (context) => [
        for (final range in ProgressRange.values)
          PopupMenuItem<ProgressRange>(
            value: range,
            height: 42,
            child: Row(
              children: [
                Icon(
                  range == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: range == selected
                      ? k.colors.primary
                      : k.colors.textMuted,
                ),
                const SizedBox(width: 9),
                Text(
                  range.label,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 12.5,
                    color: range == selected
                        ? k.colors.primary
                        : k.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
      // White, with the words in the app's green: a solid green pill here
      // was one more block of the same colour as everything the screen is
      // measuring. The shadow and the chevron keep it reading as a control.
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 9, 8),
        decoration: BoxDecoration(
          color: k.colors.surface,
          borderRadius: BorderRadius.circular(k.geometry.pillRadius),
          border: Border.all(color: k.colors.outline),
          boxShadow: k.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_outlined, size: 15, color: k.colors.primary),
            const SizedBox(width: 7),
            Text(
              selected.label,
              style: k.text.captionStrong.copyWith(
                fontSize: 12.5,
                color: k.colors.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 18, color: k.colors.primary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat tiles
// ---------------------------------------------------------------------------

class _StatTiles extends StatelessWidget {
  const _StatTiles({
    required this.range,
    required this.stats,
    required this.copy,
  });

  final ProgressRange range;
  final RangeStats stats;
  final ProgressCopy copy;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final isAllTime = range == ProgressRange.allTime;

    final tiles = <Widget>[
      _StatTile(
        top: PercentRing(percent: stats.percent, size: 42, strokeWidth: 5),
        label: AppContent.statCompletionRate,
        labelColor: k.colors.accent,
        // Named, not a bare ratio. "22 / 22" under a percentage reads as a
        // count of days, and somebody three days into using the app quite
        // reasonably wonders where twenty-two of them came from. They are
        // check-ins: habits times days.
        note: AppContent.checkInCount(stats.completed),
        info: 'Scheduled habit check-ins you completed in this period.',
      ),
      if (isAllTime)
        _StatTile(
          top: _TileIconValue(
            icon: Icons.star,
            color: k.colors.star,
            value: '${stats.bestStreak}',
          ),
          label: AppContent.statBestStreak,
          note: 'Your longest streak ever!',
          info: 'The longest run of consecutive days you showed up.',
        )
      else
        _StatTile(
          top: _TileIconValue(
            icon: Icons.local_fire_department,
            color: k.colors.flame,
            value: '${stats.currentStreak}',
          ),
          label: AppContent.statDayStreak,
          // "days in a row" said again what "Day Streak" had just said.
          note: stats.currentStreak == 0 ? AppContent.streakNone : '',
          info: 'Consecutive days with at least one habit completed.',
        ),
      _StatTile(
        top: _TileIconValue(
          icon: Icons.bar_chart,
          color: k.colors.accent,
          value: '${isAllTime ? stats.totalHabits : stats.activeHabits}',
        ),
        label: isAllTime
            ? AppContent.statTotalHabits
            : AppContent.statActiveHabits,
        // No "of 8 tracked" underneath. The number above is the answer to
        // the label above it; the total includes habits that were stopped,
        // which is a different question nobody asked here.
        note: isAllTime ? AppContent.everTracked : AppContent.nowTracking,
        info: 'Habits you are currently tracking.',
      ),
      if (isAllTime)
        _StatTile(
          top: _TileIconValue(
            icon: Icons.trending_up,
            color: k.colors.accent,
            value: '${stats.daysActive}',
          ),
          label: AppContent.statDaysActive,
          note: 'Since you started',
          info: 'Days since your first habit was created.',
        )
      // During a first week there is no previous one to be up against, and
      // "+100 pts" for beating a period the user was not here for is a
      // compliment about nothing. Perfect days is the honest thing to show
      // instead — it is about this period only.
      else if (!stats.hasPrevious)
        _StatTile(
          top: _TileIconValue(
            icon: Icons.workspace_premium,
            color: k.colors.star,
            value: '${stats.perfectDays}',
          ),
          label: AppContent.statPerfectDays,
          note: AppContent.comparisonNone,
          info: 'Days in this period where every scheduled habit was done.',
        )
      else
        _StatTile(
          top: _TileIconValue(
            icon: Icons.trending_up,
            color: k.colors.accent,
            value: '${stats.delta >= 0 ? '+' : ''}${stats.delta} pts',
            fontSize: 15,
          ),
          label: copy.comparisonLabel,
          note: AppContent.comparisonBlurb(
            stats.previousPercent,
            stats.percent,
          ),
          info: 'Change against the previous period.',
        ),
    ];

    // IntrinsicHeight gives the tiles a common height; a bare `stretch` would
    // be unbounded inside the enclosing ListView.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == tiles.length - 1 ? 0 : 7),
                child: tiles[i],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.top,
    required this.label,
    required this.note,
    required this.info,
    this.labelColor,
  });

  final Widget top;
  final String label;
  final String note;
  final String info;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Tooltip(
      message: info,
      triggerMode: TooltipTriggerMode.tap,
      child: KCard(
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            top,
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: k.text.captionStrong.copyWith(
                fontSize: 9.5,
                color: labelColor ?? k.colors.textPrimary,
              ),
              maxLines: 2,
            ),
            Text(
              note,
              textAlign: TextAlign.center,
              style: k.text.caption.copyWith(fontSize: 8.5, height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIconValue extends StatelessWidget {
  const _TileIconValue({
    required this.icon,
    required this.color,
    required this.value,
    this.fontSize = 18,
  });

  final IconData icon;
  final Color color;
  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: 42,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          FittedBox(
            child: Text(
              value,
              style: k.text.statValue.copyWith(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.range,
    required this.stats,
    required this.copy,
  });

  final ProgressRange range;
  final RangeStats stats;
  final ProgressCopy copy;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.chartTitle,
                  style: k.text.sectionTitle.copyWith(fontSize: 16),
                ),
              ),
              Icon(Icons.info_outline, size: 12, color: k.colors.textMuted),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            copy.chartSubtitle,
            style: k.text.caption.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 10),
          // A chart of nothing is a row of empty axes, which reads as broken
          // rather than as empty. Say so instead.
          if (stats.series.every((p) => p.percent <= 0))
            const _NoChartData()
          else if (range == ProgressRange.allTime)
            ProgressLineChart(points: stats.series)
          else
            ProgressBarChart(
              points: stats.series,
              height: 92,
              showAxis: range == ProgressRange.year,
              dense: range == ProgressRange.year,
            ),
        ],
      ),
    );
  }
}

/// What a chart says when it has nothing to draw.
///
/// Given the same height the chart would have had, so the card does not
/// collapse and then jump back to size the moment a first check-in lands.
class _NoChartData extends StatelessWidget {
  const _NoChartData();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.insights_rounded,
    title: AppContent.chartEmptyTitle,
    body: AppContent.chartEmptyBody,
    ghost: GhostKind.bars,
    card: false,
    // The height the chart itself takes, so the card does not change size
    // when the first check-in lands.
    height: 104,
  );
}

// ---------------------------------------------------------------------------
// Habit breakdown
// ---------------------------------------------------------------------------

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.range,
    required this.stats,
    required this.copy,
  });

  final ProgressRange range;
  final RangeStats stats;
  final ProgressCopy copy;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final showStreak = range == ProgressRange.week;

    return KCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppContent.progressBreakdownTitle,
                      style: k.text.sectionTitle.copyWith(fontSize: 16),
                    ),
                    Text(
                      copy.breakdownSubtitle,
                      style: k.text.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                child: Text(
                  AppContent.progressCompletedColumn,
                  textAlign: TextAlign.center,
                  style: k.text.caption.copyWith(fontSize: 9),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ),
              SizedBox(
                width: showStreak ? 58 : 34,
                child: Text(
                  showStreak
                      ? AppContent.calendarStreakLabel
                      : AppContent.progressRateColumn,
                  textAlign: TextAlign.right,
                  style: k.text.caption.copyWith(fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The one scrolling region on the page. `shrinkWrap` keeps the card
          // to its content when there are only a few habits, so a short list
          // does not leave the card stretched over empty space.
          if (stats.breakdown.isEmpty)
            const Flexible(
              child: EmptyState(
                icon: Icons.donut_large_rounded,
                title: AppContent.breakdownEmptyTitle,
                body: AppContent.breakdownEmptyBody,
                card: false,
                height: 140,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: stats.breakdown.length,
                itemBuilder: (context, i) => _BreakdownRow(
                  row: stats.breakdown[i],
                  showStreak: showStreak,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.row, required this.showStreak});

  final HabitBreakdown row;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final accent = k.colors.accentFor(row.habit.iconKey);
    // The same hue this habit wears on the board, so a bar here and a band
    // there are the same habit at a glance.
    final colour = context.watch<AppState>().colorFor(row.habit);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: accent.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.forKey(row.habit.iconKey),
              size: 12,
              color: accent.foreground,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 4,
            child: Text(
              row.habit.name,
              style: k.text.bodyStrong.copyWith(
                fontSize: 10.5,
                color: row.habit.isArchived
                    ? k.colors.textMuted
                    : k.colors.textPrimary,
                decoration: row.habit.isArchived
                    ? TextDecoration.lineThrough
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: row.percent / 100,
                  backgroundColor: k.colors.accentTrack,
                  valueColor: AlwaysStoppedAnimation(
                    habitShade(colour, row.percent / 100),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(
              '${row.completed} / ${row.scheduled}',
              textAlign: TextAlign.center,
              style: k.text.caption.copyWith(fontSize: 9.5),
            ),
          ),
          SizedBox(
            width: showStreak ? 58 : 34,
            child: showStreak
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 12,
                          color: k.colors.flame,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${row.streak} days',
                          style: k.text.captionStrong.copyWith(fontSize: 9.5),
                        ),
                      ],
                    ),
                  )
                : Text(
                    '${row.percent}%',
                    textAlign: TextAlign.right,
                    style: k.text.captionStrong.copyWith(fontSize: 10),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The encouraging line under the numbers.
///
/// Deliberately one line of copy in a soft card, matching the Calendar
/// banner — the earlier version was three stacked paragraphs and it was what
/// pushed this page past a single screen.
class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.stats, required this.copy});

  final RangeStats stats;
  final ProgressCopy copy;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final n = NumberFormat.decimalPattern();
    final banner = AppContent.progressBanner(
      stats.range,
      completed: stats.completed,
      scheduled: stats.scheduled,
      percent: stats.percent,
    );

    return KCard(
      soft: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Icon(Icons.eco, size: 17, color: k.colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  banner.title,
                  style: k.text.cardTitle.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  banner.line ??
                      '${copy.bannerVerb} ${n.format(stats.completed)} of '
                          '${n.format(stats.scheduled)} (${stats.percent}%)',
                  style: k.text.caption.copyWith(fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ScriptNote(
            text: banner.script,
            align: TextAlign.right,
            fontSize: 12,
            underline: false,
          ),
        ],
      ),
    );
  }
}
