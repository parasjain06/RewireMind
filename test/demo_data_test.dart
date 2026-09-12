import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/models/progress_range.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// The bundled demo history.
///
/// It exists so the board, the charts and the challenge can be looked at
/// without three months of waiting, which means it has to actually put
/// something on all three. A dataset that loads but leaves every chart empty
/// would be worse than none, because it would look like the charts were broken.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> load() =>
      rootBundle.loadString('assets/demo/demo_backup.json');

  /// What the row actually restores: the file, slid forward to end yesterday.
  Future<String> loadFresh(AppState state) async => AppState.freshenDemo(
    await load(),
    state.today.subtract(const Duration(days: 1)),
  );

  test('it is a backup the app would accept from a file', () async {
    final backup = AppState.inspectBackup(await load());
    expect(
      backup,
      isNotNull,
      reason:
          'the row goes through the same inspect/restore a real file does, '
          'so it cannot smuggle in a dataset a restore would have refused',
    );
    expect(backup!.habits, 8);
    expect(backup.checkIns, greaterThan(300));
  });

  test('restoring it fills the board, the charts and the challenge', () async {
    final state = await emptyState();
    await state.restoreBackup(AppState.inspectBackup(await loadFresh(state))!);

    expect(state.everyHabit, hasLength(8));

    // The board: enough history to scroll, and partial days in it — a board of
    // nothing but full and empty cells would not show what it is for.
    expect(
      state.today.difference(state.firstTrackedDay).inDays,
      greaterThan(60),
    );
    final partials = <double>[];
    for (final habit in state.everyHabit) {
      for (var back = 0; back < 60; back++) {
        final value = state.valueOf(
          habit.id,
          state.today.subtract(Duration(days: back)),
        );
        if (value > 0 && value < habit.target) partials.add(value);
      }
    }
    expect(partials, isNotEmpty, reason: 'nothing to shade');

    // The charts.
    for (final range in ProgressRange.values) {
      final stats = state.statsFor(range);
      expect(stats.scheduled, greaterThan(0), reason: '$range');
    }

    // The challenge.
    expect(
      state.perfectStreak,
      greaterThan(0),
      reason: 'the run is what the path draws, so the demo has to have one',
    );
  });

  test('the demo is still current a week after it was made', () async {
    // It was a fixed file, and a demo goes stale by the day: two days after
    // its last entry the run it was built to show had been broken by a day
    // nobody logged. Loaded at any distance from the file's own dates, it has
    // to end yesterday with the run intact.
    final state = await emptyState();
    for (final days in [1, 2, 5, 9, 30, 200]) {
      final end = state.today.subtract(const Duration(days: 1));
      final raw = AppState.freshenDemo(
        await load(),
        end.add(Duration(days: days - 1)),
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final keys = <String>{
        for (final days in (json['logs'] as Map).values)
          ...(days as Map).keys.cast<String>(),
      };
      final latest = keys.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      expect(
        DateTime.parse(latest),
        dateOnlyForTest(end.add(Duration(days: days - 1))),
        reason: 'ends on the day asked for, $days days out',
      );
    }
  });

  test('weekday habits stay on weekdays when it slides', () async {
    // Moving everything by an odd number of days would put a weekdays-only
    // habit's check-ins on a Saturday and leave its Monday empty.
    final state = await emptyState();
    final raw = AppState.freshenDemo(
      await load(),
      state.today.add(const Duration(days: 40)),
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    for (final habit in json['habits'] as List) {
      final weekdays = (habit['activeWeekdays'] as List).cast<int>();
      if (weekdays.length == 7) continue;
      final days = (json['logs'] as Map)[habit['id']] as Map;
      for (final key in days.keys) {
        expect(
          weekdays,
          contains(DateTime.parse(key as String).weekday),
          reason: '${habit['name']} logged on an unscheduled day, $key',
        );
      }
    }
  });

  test('a backup that already reaches the day is left alone', () async {
    final raw = await load();
    expect(AppState.freshenDemo(raw, DateTime(2026, 9, 9)), raw);
    expect(AppState.freshenDemo('not json', DateTime(2030)), 'not json');
  });

  test('every habit lands on a distinct colour', () async {
    final state = await emptyState();
    await state.restoreBackup(AppState.inspectBackup(await load())!);

    final seen = {for (final h in state.everyHabit) state.colorFor(h)};
    expect(
      seen,
      hasLength(state.everyHabit.length),
      reason:
          'two habits sharing a colour makes two rows of the board '
          'indistinguishable',
    );
  });

  test('it does not carry a photo path from another phone', () async {
    // A path from the machine that generated it would point at nothing here,
    // and the profile would fall back to the leaf with no way to tell why.
    final json = jsonDecode(await load()) as Map<String, dynamic>;
    expect((json['profile'] as Map)['photoPath'], isNull);
  });
}

DateTime dateOnlyForTest(DateTime d) => DateTime(d.year, d.month, d.day);
