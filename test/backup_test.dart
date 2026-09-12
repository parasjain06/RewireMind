import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// Restoring replaces everything, so the two things worth proving are that a
/// good file comes back intact and that a bad one cannot get far enough to do
/// any damage.
void main() {
  test('a backup survives the round trip', () async {
    final source = await seededState();
    final habits = source.everyHabit.length;
    final checkIns = source.checkInCount;
    final name = source.profile.name;
    final raw = jsonEncode(source.exportAll());

    expect(habits, greaterThan(0));
    expect(checkIns, greaterThan(0));

    final backup = AppState.inspectBackup(raw);
    expect(backup, isNotNull);
    expect(backup!.habits, habits);
    expect(
      backup.checkIns,
      checkIns,
      reason: 'the summary shown before restoring has to match what lands',
    );
    expect(backup.name, name);

    // Onto a different install entirely.
    final target = await emptyState();
    expect(target.everyHabit, isEmpty);

    await target.restoreBackup(backup);
    expect(target.everyHabit.length, habits);
    expect(target.checkInCount, checkIns);
    expect(target.profile.name, name);

    // And it was written, not just held in memory.
    final reopened = await reopen();
    expect(reopened.everyHabit.length, habits);
    expect(reopened.checkInCount, checkIns);
  });

  test('anything that is not a backup is refused before it can be applied', () {
    for (final raw in [
      '',
      'not json at all',
      '[]',
      '{}',
      '{"app":"something-else","habits":[],"logs":{}}',
      // Right app, but the shapes restoring depends on are missing.
      '{"app":"rewiremind"}',
      '{"app":"rewiremind","habits":{},"logs":{}}',
    ]) {
      expect(AppState.inspectBackup(raw), isNull, reason: 'accepted: $raw');
    }
  });

  test('a backup written under the old name still restores', () {
    // The app was called RewireMind when the export format was set, and
    // somebody's backup from then should not be refused over a rename.
    final old = AppState.inspectBackup(
      '{"app":"rewiremind","habits":[],"logs":{"h":{"2026-01-01":1}}}',
    );
    expect(old, isNotNull);
    expect(old!.checkIns, 1);
  });

  test('a backup of an empty install is still a valid backup', () async {
    final state = await emptyState();
    final backup = AppState.inspectBackup(jsonEncode(state.exportAll()));

    expect(backup, isNotNull);
    expect(backup!.habits, 0);
    expect(backup.checkIns, 0);
  });
}
