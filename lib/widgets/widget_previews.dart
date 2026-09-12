import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/day_phase.dart';
import '../models/stats.dart';
import '../content/widget_content.dart';
import '../notifications/home_widget_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'illustrations.dart';

/// The home screen widgets, drawn in Flutter for the Widgets screen.
///
/// Each one is a copy of its Android layout, in the same colours, sizes and
/// order, and filled with the same data — so what you pick is what lands on
/// the home screen, rather than an icon standing in for it.
///
/// The colours are the ones in `res/drawable/wm_panel_*.xml` and
/// `res/values/wm_ink.xml`. Change one side and change the other.
class WidgetPalette {
  const WidgetPalette._({
    required this.panel,
    required this.rim,
    required this.ink,
    required this.soft,
    required this.faint,
    required this.accentText,
    required this.fill,
    required this.chip,
    required this.tickOff,
  });

  final List<Color> panel;
  final Color rim;
  final Color ink;
  final Color soft;
  final Color faint;
  final Color accentText;
  final Color fill;
  final Color chip;
  final Color tickOff;

  static WidgetPalette of(DayPhase phase) => switch (phase) {
    DayPhase.night => _night,
    DayPhase.earlyMorning => _dawn,
    DayPhase.day => _day,
  };

  static const _day = WidgetPalette._(
    panel: [Color(0xFFF7FCFA), Color(0xFFEAF5F1), Color(0xFFDFEEF5)],
    rim: Color(0xA6FFFFFF),
    ink: Color(0xFF16261D),
    soft: Color(0xFF5E7168),
    faint: Color(0xFF9DADA5),
    accentText: Color(0xFF1D5E38),
    fill: Color(0xFF2E7D4F),
    chip: Color(0x1F2E7D4F),
    tickOff: Color(0xFF8FA39A),
  );

  static const _dawn = WidgetPalette._(
    panel: [Color(0xFFFFF9F3), Color(0xFFFFEEDF), Color(0xFFFBE4D6)],
    rim: Color(0xA6FFFFFF),
    ink: Color(0xFF16261D),
    soft: Color(0xFF5E7168),
    faint: Color(0xFF9DADA5),
    accentText: Color(0xFF1D5E38),
    fill: Color(0xFF2E7D4F),
    chip: Color(0x1F2E7D4F),
    tickOff: Color(0xFF8FA39A),
  );

  static const _night = WidgetPalette._(
    panel: [Color(0xFF22324B), Color(0xFF1B2940), Color(0xFF152034)],
    rim: Color(0x38FFFFFF),
    ink: Color(0xFFF1F6F3),
    soft: Color(0xFFC3D0D9),
    faint: Color(0xFF72859B),
    accentText: Color(0xFFB6ECCB),
    fill: Color(0xFF52A08A),
    chip: Color(0x3352A08A),
    tickOff: Color(0xFF7B8FA6),
  );
}

/// The system font, as the widget uses, rather than the app's Poppins.
TextStyle _t(double size, Color color, {bool strong = false}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: size,
  height: 1.2,
  color: color,
  fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
);

/// A widget's glass pane, at a given size in dp.
class _Pane extends StatelessWidget {
  const _Pane({
    required this.size,
    required this.palette,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Size size;
  final WidgetPalette palette;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.panel,
        ),
        border: Border.all(color: palette.rim, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.palette, {this.size = 11.5});

  final String text;
  final WidgetPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size < 11 ? 7 : 9,
        vertical: size < 11 ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: _t(size, palette.accentText, strong: true)),
    );
  }
}

// ---------------------------------------------------------------------------
// Today's checklist
// ---------------------------------------------------------------------------

class ChecklistPreview extends StatelessWidget {
  const ChecklistPreview({super.key, required this.state});

  static const size = Size(250, 196);

  /// Shown when there are no habits yet, so the preview still shows the idea.
  static const _sample = [
    ('Drink water', true),
    ('Read 10 pages', true),
    ('Walk 20 min', false),
    ('Meditate', false),
    ('Journal', false),
  ];

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = WidgetPalette.of(state.activePhase);
    final today = state.today;
    final real = [
      for (final habit in state.scheduledOn(today))
        (habit.name, state.isComplete(habit, today)),
    ];
    final tasks = state.everyHabit.isEmpty ? _sample : real;
    // What is left first, as on the widget.
    final ordered = [...tasks.where((t) => !t.$2), ...tasks.where((t) => t.$2)];
    const room = 5;
    final shown = ordered.length > room ? room - 1 : ordered.length;
    final done = tasks.where((t) => t.$2).length;

    return _Pane(
      size: size,
      palette: p,
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Today', style: _t(16, p.ink, strong: true)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  DateFormat('EEE d MMM').format(today),
                  style: _t(12, p.soft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tasks.isNotEmpty)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Chip('$done of ${tasks.length} done', p),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Expanded(
              child: Center(
                child: Text('Nothing due today', style: _t(13, p.soft)),
              ),
            )
          else ...[
            for (var i = 0; i < shown; i++)
              _TaskRow(name: ordered[i].$1, done: ordered[i].$2, palette: p),
            if (ordered.length > shown)
              SizedBox(
                height: 26,
                child: Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+${ordered.length - shown} more',
                      style: _t(13.5, p.soft),
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

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.name,
    required this.done,
    required this.palette,
  });

  final String name;
  final bool done;
  final WidgetPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 17,
            color: done ? p.fill : p.tickOff,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(13.5, done ? p.faint : p.ink).copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: p.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week and month
// ---------------------------------------------------------------------------

/// One day's circle, marked the way the widget marks it.
class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.day,
    required this.status,
    required this.isToday,
    required this.palette,
    this.size = 24,
    this.fontSize = 11.5,
  });

  final int day;
  final DayStatus status;
  final bool isToday;
  final WidgetPalette palette;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final soft = p.fill.withValues(alpha: 0.28);
    final future = status == DayStatus.future;

    Color? fill;
    Border? ring;
    var text = p.soft;
    var inner = 0.0;
    if (future) {
      text = p.faint;
    } else if (isToday) {
      text = p.ink;
      switch (status) {
        case DayStatus.all:
          fill = p.fill;
          text = Colors.white;
          inner = 3;
          ring = Border.all(color: p.fill, width: 1.5);
        case DayStatus.some:
          fill = soft;
          ring = Border.all(color: p.fill, width: 2);
        default:
          ring = Border.all(color: p.fill, width: 2);
      }
    } else {
      switch (status) {
        case DayStatus.all:
          fill = p.fill;
          text = Colors.white;
        case DayStatus.some:
          fill = soft;
          text = p.ink;
        case DayStatus.none:
          ring = Border.all(
            color: p.fill.withValues(
              alpha: p == WidgetPalette._night ? 0.4 : 0.25,
            ),
            width: 1.2,
          );
        default:
          break;
      }
    }

    final label = Text(
      '$day',
      style: _t(fontSize, text, strong: isToday || status == DayStatus.all),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: ring,
        color: inner == 0 ? fill : null,
      ),
      alignment: Alignment.center,
      child: inner == 0
          ? label
          : Container(
              margin: EdgeInsets.all(inner),
              decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
              alignment: Alignment.center,
              child: label,
            ),
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class WeekPreview extends StatelessWidget {
  const WeekPreview({super.key, required this.state});

  static const size = Size(320, 68);

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = WidgetPalette.of(state.activePhase);
    final today = state.today;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );

    return _Pane(
      size: size,
      palette: p,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                  final isToday = day == today;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdays[i],
                        style: _t(
                          10,
                          isToday ? p.accentText : p.soft,
                          strong: isToday,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _DayMark(
                        day: day.day,
                        status: state.dayStatus(day),
                        isToday: isToday,
                        palette: p,
                        size: 28,
                        fontSize: 12.5,
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MonthPreview extends StatelessWidget {
  const MonthPreview({super.key, required this.state, this.compact = true});

  /// Three cells by two, where the widget starts; the roomy one is what it
  /// becomes when stretched. Both match their Android layouts.
  static Size sizeOf({required bool compact}) =>
      compact ? const Size(232, 176) : const Size(300, 262);

  final AppState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = sizeOf(compact: compact);
    final cell = compact ? 17.0 : 24.0;
    final p = WidgetPalette.of(state.activePhase);
    final today = state.today;
    final first = DateTime(today.year, today.month, 1);
    final offset = first.weekday - 1;
    final length = DateTime(today.year, today.month + 1, 0).day;
    final weeks = ((offset + length) / 7).ceil();
    final streak = state.perfectStreak;

    return _Pane(
      size: size,
      palette: p,
      padding: compact
          ? const EdgeInsets.fromLTRB(7, 8, 7, 6)
          : const EdgeInsets.fromLTRB(10, 11, 10, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 4),
            child: Row(
              children: [
                Text(
                  DateFormat('MMMM').format(today),
                  style: _t(compact ? 12.5 : 15, p.ink, strong: true),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${today.year}',
                    style: _t(compact ? 11 : 13, p.soft),
                  ),
                ),
                if (streak >= 2)
                  _Chip(
                    compact ? '🔥 $streak' : '🔥 $streak-day streak',
                    p,
                    size: compact ? 10 : 11.5,
                  ),
              ],
            ),
          ),
          SizedBox(height: compact ? 3 : 6),
          Row(
            children: [
              for (final d in _weekdays)
                Expanded(
                  child: Text(
                    compact ? d.substring(0, 1) : d,
                    textAlign: TextAlign.center,
                    style: _t(compact ? 9 : 10, p.soft),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          for (var r = 0; r < weeks; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: Center(
                        child: Builder(
                          builder: (context) {
                            final date = r * 7 + c - offset + 1;
                            if (date < 1 || date > length) {
                              return const SizedBox.shrink();
                            }
                            final day = DateTime(today.year, today.month, date);
                            return _DayMark(
                              day: date,
                              status: state.dayStatus(day),
                              isToday: day == today,
                              palette: p,
                              size: cell,
                              fontSize: compact ? 9 : 11.5,
                            );
                          },
                        ),
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

// ---------------------------------------------------------------------------
// The mascot, in its three sizes
// ---------------------------------------------------------------------------

/// Which character the widget shows at each hour — the same day in the life
/// as `HOURS` in RewireMindWidgetProvider.kt, in the app's own animations.
const _mascotByHour = [
  'sleep', 'sleep', 'sleep', 'sleep', 'sleep', // 00-04
  'wake', 'brush', 'towel', 'coffee', 'hero', // 05-09
  'jog', 'focus', 'lunch', 'coffee', 'focus', // 10-14
  'jog', 'hero', 'heart', 'dinner', 'focus', // 15-19
  'heart', 'hero_night', 'sleep', 'sleep', // 20-23
];

/// The hour walked into a pinned time of day, as the widget does.
int _hourInPhase(int hour, DayPhase phase, bool pinned) {
  if (!pinned) return hour;
  switch (phase) {
    case DayPhase.earlyMorning:
      return hour >= 5 && hour <= 9 ? hour : 5 + hour % 5;
    case DayPhase.day:
      return hour >= 10 && hour <= 18 ? hour : 10 + hour % 9;
    case DayPhase.night:
      const night = [19, 20, 21, 22, 23, 0, 1, 2, 3, 4];
      return hour >= 19 || hour <= 4 ? hour : night[hour % night.length];
  }
}

class MascotPreview extends StatefulWidget {
  const MascotPreview({super.key, required this.state, required this.kind});

  final AppState state;

  /// [WidgetKind.strip], [WidgetKind.small] or [WidgetKind.medium].
  final WidgetKind kind;

  static Size sizeOf(WidgetKind kind) => switch (kind) {
    WidgetKind.strip => const Size(320, 64),
    WidgetKind.small => const Size(150, 150),
    _ => const Size(320, 150),
  };

  @override
  State<MascotPreview> createState() => _MascotPreviewState();
}

class _MascotPreviewState extends State<MascotPreview> {
  /// Picked once, so the line does not change under your finger on rebuild.
  late final WidgetFace _face = _faceNow();

  WidgetFace _faceNow() {
    final s = widget.state;
    final scheduled = s.scheduledOn(s.today);
    return HomeWidgetService.faceFor(
      streak: s.perfectStreak,
      pathLength: kChallengeLength,
      scheduledToday: scheduled.length,
      doneToday: scheduled.where((h) => s.isComplete(h, s.today)).length,
      daysSinceSeen: s.daysSinceSeen,
      hasHabits: s.everyHabit.isNotEmpty,
      phase: s.activePhase.name,
      challengeDay: s.challengeLive ? s.challengeDay : null,
      name: s.profile.name.isEmpty ? null : s.profile.firstName,
      rng: Random(DateTime.now().hour),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final phase = s.activePhase;
    final night = phase == DayPhase.night;
    final ink = night ? const Color(0xFFF1F6F3) : const Color(0xFF16261D);
    final soft = night ? const Color(0xFFC3D0D9) : const Color(0xFF5E7168);
    final chipText = night ? const Color(0xFFB6ECCB) : const Color(0xFF1D5E38);
    final size = MascotPreview.sizeOf(widget.kind);

    final hour = _hourInPhase(DateTime.now().hour, phase, !s.followsClock);
    final character = switch (_face.mood) {
      WidgetMood.happy => 'day21',
      WidgetMood.sad => 'sleep',
      _ => _mascotByHour[hour],
    };
    final mascot = Image.asset(
      'assets/anim/$character.webp',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: night ? 0.12 : 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Text(text, style: _t(11.5, chipText, strong: true)),
    );

    final Widget content = switch (widget.kind) {
      WidgetKind.strip => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _face.shortLine,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(14, ink, strong: true),
              ),
            ),
            SizedBox(width: 62, child: mascot),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: chip(_face.streak),
              ),
            ),
          ],
        ),
      ),
      WidgetKind.small => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        child: Column(
          children: [
            Text(
              _face.shortLine,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(13, ink, strong: true),
            ),
            Expanded(child: mascot),
            chip(_face.streakShort),
          ],
        ),
      ),
      _ => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _face.line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t(15, ink, strong: true),
                  ),
                  const SizedBox(height: 3),
                  // The real widget shrinks this line to fit rather than
                  // cutting it; the preview has to do the same, or it
                  // promises a home screen something different.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(_face.sub, maxLines: 1, style: _t(11.5, soft)),
                  ),
                  const Spacer(),
                  chip(_face.streak),
                ],
              ),
            ),
            SizedBox(width: 110, child: mascot),
          ],
        ),
      ),
    };

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The sky first: the tree painter draws the sun, the ground and
            // the tree, and leaves the sky to whatever page it is on.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: context.k.colors.backgroundGradient,
                ),
              ),
            ),
            // The same sun or moon and tree the widget has: exported from
            // this painter in the first place.
            OverflowBox(
              alignment: Alignment.bottomCenter,
              maxHeight: max(size.height, 128),
              child: TreeScene(
                height: max(size.height, 128),
                treeX: 0.9,
                phase: phase,
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}
