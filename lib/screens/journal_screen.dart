import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/journal_content.dart';
import '../journal/journal_insights.dart';
import '../models/journal_entry.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/journal_widgets.dart';
import '../widgets/k_card.dart';
import 'journal_editor_screen.dart';
import '../content/premium_content.dart';
import '../widgets/premium_gate.dart';

/// The journal: every entry, and what they add up to.
///
/// Two halves. Entries is the record, newest first, each one carrying the
/// day's mood and what was actually done that day. Insights is what the
/// record is for: the month in moods, the trend, and — the part a plain
/// diary cannot do — which of your habits lift how you feel.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  static Future<void> open(BuildContext context) {
    return ifPremium(
      context,
      PremiumContent.lockedJournal,
      () => _push(context),
    );
  }

  static Future<void> _push(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const JournalScreen()));
  }

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _insights = false;
  bool _searching = false;
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _write() async {
    final template = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TemplateSheet(),
    );
    if (template == null || !mounted) return;
    await JournalEditorScreen.open(context, template: template);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: k.colors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: _searching
              ? TextField(
                  controller: _query,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: k.text.body,
                  decoration: InputDecoration(
                    hintText: JournalContent.searchHint,
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  JournalContent.title,
                  style: k.text.sectionTitle.copyWith(fontSize: 17),
                ),
          actions: [
            if (!_insights)
              IconButton(
                icon: Icon(
                  _searching ? Icons.close_rounded : Icons.search_rounded,
                  color: k.colors.primary,
                ),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query.clear();
                }),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _write,
          backgroundColor: k.colors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.edit_rounded, size: 20),
          label: Text(JournalContent.write),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                k.geometry.screenPadding,
                0,
                k.geometry.screenPadding,
                8,
              ),
              child: _Tabs(
                insights: _insights,
                onSelect: (v) => setState(() {
                  _insights = v;
                  _searching = false;
                  _query.clear();
                }),
              ),
            ),
            Expanded(
              child: _insights
                  ? const _Insights()
                  : _Entries(query: _query.text.trim().toLowerCase()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.insights, required this.onSelect});

  final bool insights;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    Widget tab(String label, IconData icon, bool on, bool value) => Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? k.colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(k.geometry.innerRadius - 3),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: on ? k.colors.primary : k.colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: k.text.captionStrong.copyWith(
                  fontSize: 13,
                  color: on ? k.colors.primary : k.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      ),
      child: Row(
        children: [
          tab(
            JournalContent.entriesTab,
            Icons.view_agenda_outlined,
            !insights,
            false,
          ),
          tab(
            JournalContent.insightsTab,
            Icons.insights_rounded,
            insights,
            true,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entries
// ---------------------------------------------------------------------------

class _Entries extends StatelessWidget {
  const _Entries({required this.query});

  final String query;

  bool _matches(JournalEntry e) {
    if (query.isEmpty) return true;
    final words = [
      ...e.lines,
      ...e.feelings.map(JournalContent.feeling),
      JournalContent.template(e.template).name,
      if (e.mood != null) JournalContent.mood(e.mood!).label,
    ].join(' ').toLowerCase();
    return words.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final all = state.journal;
    final shown = [
      for (final e in all)
        if (_matches(e)) e,
    ];

    final pad = EdgeInsets.fromLTRB(
      k.geometry.screenPadding,
      4,
      k.geometry.screenPadding,
      96,
    );

    if (all.isEmpty) {
      return ListView(
        padding: pad,
        children: const [
          _WeekStrip(),
          SizedBox(height: 12),
          EmptyState(
            icon: Icons.auto_stories_outlined,
            title: JournalContent.emptyTitle,
            body: JournalContent.emptyBody,
            height: 200,
          ),
        ],
      );
    }

    // Grouped by month, newest first.
    final children = <Widget>[
      if (query.isEmpty) ...[
        const _WeekStrip(),
        const SizedBox(height: 12),
        const _OnThisDay(),
      ],
    ];
    String? month;
    for (final e in shown) {
      final label = DateFormat('MMMM yyyy').format(e.day);
      if (label != month) {
        month = label;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(
              label.toUpperCase(),
              style: k.text.captionStrong.copyWith(
                fontSize: 11,
                letterSpacing: 0.8,
                color: k.colors.textSecondary,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EntryCard(entry: e),
        ),
      );
    }
    if (shown.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(JournalContent.noResults, style: k.text.caption),
          ),
        ),
      );
    }
    return ListView(padding: pad, children: children);
  }
}

/// This week at a glance: a face for each day with a mood.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final today = state.today;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );

    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = DateTime(
                    monday.year,
                    monday.month,
                    monday.day + i,
                  );
                  final mood = state.moodOn(day);
                  final isToday = day == today;
                  final future = day.isAfter(today);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: future
                        ? null
                        : () {
                            final entries = state.journalOn(day);
                            JournalEditorScreen.open(
                              context,
                              entry: entries.isEmpty ? null : entries.first,
                              day: day,
                            );
                          },
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: k.text.caption.copyWith(
                            fontSize: 11,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isToday
                                ? k.colors.primary
                                : k.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: future ? 0.35 : 1,
                          child: mood == null
                              ? Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isToday
                                          ? k.colors.accent
                                          : k.colors.outline,
                                      width: isToday ? 2 : 1.2,
                                    ),
                                  ),
                                )
                              : MoodFace(mood: mood, size: 30),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// An entry from a month ago or a year ago today, when there is one.
class _OnThisDay extends StatelessWidget {
  const _OnThisDay();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final t = state.today;
    for (final months in const [12, 6, 3, 1]) {
      final then = DateTime(t.year, t.month - months, t.day);
      if (then.day != t.day) continue; // no 31st in that month
      final entries = state.journalOn(then);
      if (entries.isEmpty) continue;
      final e = entries.first;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: KCard(
          soft: true,
          onTap: () => JournalEditorScreen.open(context, entry: e),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: k.colors.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${JournalContent.onThisDay} · '
                      '${JournalContent.onThisDayWhen(months)}',
                      style: k.text.captionStrong.copyWith(
                        color: k.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.hasWords
                          ? e.lines.first
                          : JournalContent.mood(e.mood ?? 3).label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: k.text.body.copyWith(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoodFace(mood: e.mood, size: 32),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final template = JournalContent.template(entry.template);
    final scheduled = state.scheduledOn(entry.day);
    final done = scheduled.where((h) => state.isComplete(h, entry.day)).length;

    return KCard(
      onTap: () => JournalEditorScreen.open(context, entry: entry),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The date, as a calendar leaf.
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  '${entry.day.day}',
                  style: k.text.pageTitle.copyWith(
                    fontSize: 24,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEE').format(entry.day).toUpperCase(),
                  style: k.text.caption.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(template.icon, size: 14, color: k.colors.accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        template.name,
                        overflow: TextOverflow.ellipsis,
                        style: k.text.captionStrong.copyWith(
                          fontSize: 11.5,
                          color: k.colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (entry.hasWords)
                  Text(
                    entry.lines.join('  ·  '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: k.text.body.copyWith(fontSize: 14, height: 1.4),
                  )
                else
                  Text(
                    entry.mood == null
                        ? '—'
                        : JournalContent.mood(entry.mood!).label,
                    style: k.text.body.copyWith(
                      fontSize: 14,
                      color: k.colors.textSecondary,
                    ),
                  ),
                if (entry.feelings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final f in entry.feelings.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: k.colors.surfaceSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            JournalContent.feeling(f),
                            style: k.text.caption.copyWith(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
                if (scheduled.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 13,
                        color: k.colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$done of ${scheduled.length} habits',
                        style: k.text.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          MoodFace(mood: entry.mood, size: 34),
        ],
      ),
    );
  }
}

/// Which kind of entry to write.
class _TemplateSheet extends StatelessWidget {
  const _TemplateSheet();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final suggested = JournalContent.suggestedFor(DateTime.now()).key;
    return Container(
      decoration: BoxDecoration(
        color: k.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: k.colors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              for (final t in JournalContent.templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: t.key == suggested
                        ? k.colors.accentSoft
                        : k.colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(k.geometry.innerRadius),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        k.geometry.innerRadius,
                      ),
                      onTap: () => Navigator.of(context).pop(t.key),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(t.icon, color: k.colors.accent, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name, style: k.text.cardTitle),
                                  Text(
                                    t.blurb,
                                    style: k.text.caption.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: k.colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
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
// Insights
// ---------------------------------------------------------------------------

class _Insights extends StatefulWidget {
  const _Insights();

  @override
  State<_Insights> createState() => _InsightsState();
}

class _InsightsState extends State<_Insights> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final t = context.read<AppState>().today;
    _month = DateTime(t.year, t.month);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final entries = state.journal;
    final moods = JournalInsights.dailyMood(entries);

    final pad = EdgeInsets.fromLTRB(
      k.geometry.screenPadding,
      4,
      k.geometry.screenPadding,
      96,
    );

    if (moods.length < 3) {
      return ListView(
        padding: pad,
        children: const [
          EmptyState(
            icon: Icons.insights_rounded,
            title: JournalContent.insightsEmptyTitle,
            body: JournalContent.insightsEmptyBody,
            ghost: GhostKind.bars,
            height: 200,
          ),
        ],
      );
    }

    final monthStart = _month;
    final monthEnd = DateTime(_month.year, _month.month + 1, 0);
    final inMonth = {
      for (final e in moods.entries)
        if (!e.key.isBefore(monthStart) && !e.key.isAfter(monthEnd))
          e.key: e.value,
    };
    final monthEntries = entries
        .where((e) => !e.day.isBefore(monthStart) && !e.day.isAfter(monthEnd))
        .length;
    final avg = inMonth.isEmpty
        ? null
        : inMonth.values.reduce((a, b) => a + b) / inMonth.length;

    final lifts = JournalInsights.lift(
      moods: moods,
      habits: state.everyHabit,
      scheduled: (h, d) => h.isActiveOnDay(d),
      done: (h, d) => state.isComplete(h, d),
    );
    final feelings = JournalInsights.feelings(
      entries,
      from: DateTime(state.today.year, state.today.month - 1, state.today.day),
    );

    return ListView(
      padding: pad,
      children: [
        // The month, at a glance.
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.chevron_left, color: k.colors.primary),
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      textAlign: TextAlign.center,
                      style: k.text.cardTitle,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.chevron_right, color: k.colors.primary),
                    onPressed:
                        DateTime(
                          _month.year,
                          _month.month + 1,
                        ).isAfter(state.today)
                        ? null
                        : () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Stat(
                    value: '$monthEntries',
                    label: JournalContent.insightsEntries,
                  ),
                  const SizedBox(width: 10),
                  _Stat(
                    value: avg == null ? '—' : avg.toStringAsFixed(1),
                    label: JournalContent.insightsAverage,
                    mood: avg?.round(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MoodMonth(month: _month, moods: moods),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(JournalContent.insightsTrend, style: k.text.cardTitle),
              const SizedBox(height: 14),
              _Trend(weeks: JournalInsights.weekly(moods, state.today)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(JournalContent.insightsLift, style: k.text.cardTitle),
              const SizedBox(height: 2),
              Text(
                JournalContent.insightsLiftBody,
                style: k.text.caption.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              if (lifts.isEmpty)
                Text(JournalContent.insightsLiftEmpty, style: k.text.caption)
              else
                for (final lift in lifts.take(5)) _LiftRow(lift: lift),
            ],
          ),
        ),
        if (feelings.isNotEmpty) ...[
          const SizedBox(height: 12),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(JournalContent.insightsFeelings, style: k.text.cardTitle),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (key, count) in feelings.take(8))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: k.colors.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${JournalContent.feeling(key)}  $count',
                          style: k.text.captionStrong.copyWith(
                            fontSize: 12,
                            color: k.colors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.mood});

  final String value;
  final String label;
  final int? mood;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        ),
        child: Row(
          children: [
            if (mood != null) ...[
              MoodFace(mood: mood, size: 30),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: k.text.statValue.copyWith(fontSize: 20)),
                  Text(label, style: k.text.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The month as a grid of moods: a coloured dot for each day with one.
class _MoodMonth extends StatelessWidget {
  const _MoodMonth({required this.month, required this.moods});

  final DateTime month;
  final Map<DateTime, int> moods;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final offset = month.weekday - 1;
    final length = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((offset + length) / 7).ceil();
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final l in letters)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: k.text.caption.copyWith(fontSize: 10.5),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < weeks; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final date = r * 7 + c - offset + 1;
                        if (date < 1 || date > length) {
                          return const SizedBox(height: 30);
                        }
                        final day = DateTime(month.year, month.month, date);
                        final mood = moods[day];
                        return Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mood == null
                                  ? k.colors.surfaceSoft
                                  : Color(JournalContent.mood(mood).colour)
                                        .withValues(alpha: 0.85),
                            ),
                            child: Text(
                              '$date',
                              style: k.text.caption.copyWith(
                                fontSize: 11,
                                fontWeight: mood == null
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                                color: mood == null
                                    ? k.colors.textMuted
                                    : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Eight weeks of average mood, as bars coloured by where they land.
class _Trend extends StatelessWidget {
  const _Trend({required this.weeks});

  final List<double?> weeks;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, avg) in weeks.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (avg != null)
                      Text(
                        avg.toStringAsFixed(1),
                        style: k.text.caption.copyWith(fontSize: 10),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: avg == null ? 4 : 12 + 64 * (avg - 1) / 4,
                      decoration: BoxDecoration(
                        color: avg == null
                            ? k.colors.accentTrack
                            : Color(JournalContent.mood(avg.round()).colour),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i == weeks.length - 1
                          ? 'Now'
                          : '${weeks.length - 1 - i}w',
                      style: k.text.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.lift});

  final HabitLift lift;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final up = lift.delta >= 0;
    final tone = up ? const Color(0xFF2E9E6E) : const Color(0xFFEE9B55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          IconChip(
            iconKey: lift.habit.iconKey,
            icon: AppIcons.forKey(lift.habit.iconKey),
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lift.habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: k.text.cardTitle.copyWith(fontSize: 14),
                ),
                Text(
                  '${lift.withDays} days with · ${lift.withoutDays} without',
                  style: k.text.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 16,
                  color: tone,
                ),
                const SizedBox(width: 4),
                Text(
                  JournalContent.lift(lift.delta),
                  style: k.text.captionStrong.copyWith(
                    fontSize: 12,
                    color: tone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
