import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rewiremind/data/storage.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/models/progress_range.dart';
import 'package:rewiremind/models/stats.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/theme/habit_shade.dart';

import 'helpers.dart';

/// ============================================================================
/// DOES THE APP AGREE WITH ITSELF?
/// ============================================================================
/// Every screen shows a different view of one set of check-ins, and each view
/// works its own numbers out. That is four chances for two screens to disagree
/// about the same fortnight, and a disagreement is worse than a wrong number:
/// it makes somebody stop trusting all of it.
///
/// So this file does the arithmetic a second time, straight off the raw logs,
/// with none of the app's own code — a deliberately dumb loop over days and
/// habits — and holds every figure the app displays against it. It runs on the
/// bundled demo data, which is the only fixture with enough shape in it to
/// catch anything: eight habits, seventy days, weekday-only schedules, part
/// days, and a deliberate broken run.
/// ============================================================================
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late List<Habit> habits;
  late Map<String, Map<String, double>> logs;
  late DateTime today;

  /// The independent answer: did this habit meet its target on this day?
  bool didIt(Habit h, DateTime d) {
    final v = logs[h.id]?[dayKey(d)] ?? 0;
    return h.target > 0 && v >= h.target;
  }

  /// The independent answer: was this habit asked for on this day?
  bool wanted(Habit h, DateTime d) {
    if (dateOnly(h.createdAt).isAfter(d)) return false;
    final off = h.archivedAt;
    if (off != null && !dateOnly(off).isAfter(d)) return false;
    return h.activeWeekdays.contains(d.weekday);
  }

  List<DateTime> daysFrom(DateTime start, DateTime end) => [
    for (
      var d = dateOnly(start);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    )
      d,
  ];

  setUpAll(() async {
    disableLivePhaseTicker();
    disableNotificationPlugin();
    SharedPreferences.setMockInitialValues({});

    // The very file the "load demo data" row on the Your Data screen reads, so
    // this checks the fixture people actually see and not a fixture written to
    // agree with the code.
    final raw = await rootBundle.loadString('assets/demo/demo_backup.json');
    final backup = jsonDecode(raw) as Map<String, dynamic>;
    final summary = AppState.inspectBackup(raw)!;

    final storage = await RewireMindStorage.open();
    state = AppState(storage);
    await state.load();
    await state.restoreBackup(summary);

    habits = state.everyHabit;
    today = state.today;
    logs = {
      for (final h in habits)
        h.id: {
          for (final entry
              in ((backup['logs'] as Map)[h.id] as Map? ?? const {}).entries)
            entry.key as String: (entry.value as num).toDouble(),
        },
    };
  });

  test('the fixture is loaded and has some shape to it', () {
    expect(habits, hasLength(8));
    expect(
      habits.where((h) => h.activeWeekdays.length < 7),
      isNotEmpty,
      reason: 'a weekday-only habit is what catches "scheduled" bugs',
    );
    expect(
      logs.values.expand((m) => m.values).where((v) => v > 0),
      hasLength(greaterThan(200)),
    );
  });

  // -------------------------------------------------------------------------
  // Home
  // -------------------------------------------------------------------------
  group('Home', () {
    test('the day count matches the days it counts', () {
      for (final d in daysFrom(
        today.subtract(const Duration(days: 70)),
        today,
      )) {
        final scheduled = habits.where((h) => wanted(h, d)).toList();
        final done = scheduled.where((h) => didIt(h, d)).length;

        expect(
          state.scheduledOn(d).map((h) => h.id).toSet(),
          scheduled.map((h) => h.id).toSet(),
          reason: 'scheduled habits on $d',
        );
        expect(state.completedCountOn(d), done, reason: 'completed on $d');
      }
    });

    test('the flame is the run of days with every scheduled habit done', () {
      var run = 0;
      // Today counts if it is already finished, but an unfinished today does
      // not break a run that is still alive — the same rule the app applies.
      for (var d = today; ; d = d.subtract(const Duration(days: 1))) {
        final scheduled = habits.where((h) => wanted(h, d)).toList();
        final perfect =
            scheduled.isNotEmpty && scheduled.every((h) => didIt(h, d));
        if (perfect) {
          run++;
        } else if (d == today) {
          continue; // today is allowed to be unfinished
        } else {
          break;
        }
        if (d.isBefore(today.subtract(const Duration(days: 400)))) break;
      }
      expect(state.currentStreak, run);
    });

    test('perfect days this week is a count of this week', () {
      final monday = startOfWeek(today);
      final perfect = daysFrom(monday, today).where((d) {
        final scheduled = habits.where((h) => wanted(h, d)).toList();
        return scheduled.isNotEmpty && scheduled.every((h) => didIt(h, d));
      }).length;

      expect(state.statsFor(ProgressRange.week).perfectDays, perfect);
    });
  });

  // -------------------------------------------------------------------------
  // Calendar
  // -------------------------------------------------------------------------
  group('Calendar', () {
    test('every dot agrees with the day under it', () {
      for (final d in daysFrom(
        today.subtract(const Duration(days: 70)),
        today,
      )) {
        final scheduled = habits.where((h) => wanted(h, d)).toList();
        final done = scheduled.where((h) => didIt(h, d)).length;

        final expected = scheduled.isEmpty
            ? DayStatus.empty
            : done == 0
            ? DayStatus.none
            : done == scheduled.length
            ? DayStatus.all
            : DayStatus.some;

        expect(state.dayStatus(d), expected, reason: 'status on $d');
      }
    });

    test('tomorrow is future, whatever is in the log', () {
      expect(
        state.dayStatus(today.add(const Duration(days: 1))),
        DayStatus.future,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Progress
  // -------------------------------------------------------------------------
  group('Progress', () {
    /// The rate the app quotes for a range, worked out again by hand.
    (int, int) tally(DateTime start, DateTime end) {
      var completed = 0;
      var scheduled = 0;
      for (final d in daysFrom(start, end.isAfter(today) ? today : end)) {
        for (final h in habits) {
          if (!wanted(h, d)) continue;
          scheduled++;
          if (didIt(h, d)) completed++;
        }
      }
      return (completed, scheduled);
    }

    for (final range in ProgressRange.values) {
      test('${range.name}: the rate is completed over scheduled', () {
        final stats = state.statsFor(range);
        final bounds = state.boundsFor(range);
        final (completed, scheduled) = tally(bounds.start, bounds.end);

        expect(
          stats.completed,
          completed,
          reason: 'completed in ${range.name}',
        );
        expect(
          stats.scheduled,
          scheduled,
          reason: 'scheduled in ${range.name}',
        );
        expect(
          stats.percent,
          scheduled == 0 ? 0 : ((completed / scheduled) * 100).round(),
          reason: 'the headline rate for ${range.name}',
        );
      });

      test('${range.name}: the breakdown adds up to the headline', () {
        final stats = state.statsFor(range);
        var completed = 0;
        var scheduled = 0;
        for (final row in stats.breakdown) {
          completed += row.completed;
          scheduled += row.scheduled;
        }
        expect(
          (completed, scheduled),
          (stats.completed, stats.scheduled),
          reason:
              'the rows and the total are the same check-ins for '
              '${range.name}, so they cannot disagree',
        );
      });

      test('${range.name}: no bar claims more than 100%', () {
        for (final point in state.statsFor(range).series) {
          expect(point.percent, inInclusiveRange(0, 100), reason: point.label);
          if (point.isFuture) {
            expect(point.percent, 0, reason: 'a day that has not happened');
          }
        }
      });
    }

    test('every breakdown row is that habit, on its own', () {
      final stats = state.statsFor(ProgressRange.month);
      final bounds = state.boundsFor(ProgressRange.month);

      for (final row in stats.breakdown) {
        var completed = 0;
        var scheduled = 0;
        for (final d in daysFrom(
          bounds.start,
          bounds.end.isAfter(today) ? today : bounds.end,
        )) {
          if (!wanted(row.habit, d)) continue;
          scheduled++;
          if (didIt(row.habit, d)) completed++;
        }
        expect(row.completed, completed, reason: '${row.habit.name} completed');
        expect(row.scheduled, scheduled, reason: '${row.habit.name} scheduled');
        expect(
          row.percent,
          scheduled == 0 ? 0 : ((completed / scheduled) * 100).round(),
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // The board, and the one place two views could contradict each other
  // -------------------------------------------------------------------------
  group('the board', () {
    test('a block is as deep as the day was full', () {
      for (final h in habits) {
        for (final d in daysFrom(
          today.subtract(const Duration(days: 69)),
          today,
        )) {
          final v = logs[h.id]?[dayKey(d)] ?? 0;
          final fraction = doneFraction(h, state.valueOf(h.id, d));

          expect(state.valueOf(h.id, d), v, reason: '${h.name} on $d');
          expect(
            fraction,
            h.target <= 0
                ? (v > 0 ? 1.0 : 0.0)
                : (v / h.target).clamp(0.0, 1.0),
            reason: 'depth of ${h.name} on $d',
          );
        }
      }
    });

    test('a full block and a completed day are the same claim', () {
      // The thing that made the numbers look wrong: the board draws part days
      // in mid-tone while every rate on Progress counts only whole ones. That
      // is allowed — but a block drawn at full depth must mean the same as a
      // day the rates count, or the two really are contradicting each other.
      for (final h in habits) {
        for (final d in daysFrom(
          today.subtract(const Duration(days: 69)),
          today,
        )) {
          if (!wanted(h, d)) continue;
          final full = doneFraction(h, state.valueOf(h.id, d)) == 1.0;
          expect(
            full,
            didIt(h, d),
            reason: 'a full block on ${h.name}, $d, must be a completed day',
          );
        }
      }
    });

    test('a day with nothing logged is drawn as nothing at all', () {
      for (final h in habits) {
        for (final d in daysFrom(
          today.subtract(const Duration(days: 69)),
          today,
        )) {
          if ((logs[h.id]?[dayKey(d)] ?? 0) > 0) continue;
          expect(
            doneFraction(h, state.valueOf(h.id, d)),
            0,
            reason: 'nothing logged for ${h.name} on $d',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // The 21-day path
  // -------------------------------------------------------------------------
  test('the challenge counts unbroken perfect days and nothing else', () {
    var run = 0;
    for (var d = today; ; d = d.subtract(const Duration(days: 1))) {
      final scheduled = habits.where((h) => wanted(h, d)).toList();
      final perfect =
          scheduled.isNotEmpty && scheduled.every((h) => didIt(h, d));
      if (perfect) {
        run++;
      } else if (d == today) {
        continue;
      } else {
        break;
      }
      if (d.isBefore(today.subtract(const Duration(days: 400)))) break;
    }
    expect(state.perfectStreak, run);
    expect(
      state.perfectStreak,
      state.currentStreak,
      reason: 'both count the same thing, so they must never differ',
    );
  });
}
