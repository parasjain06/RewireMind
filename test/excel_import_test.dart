import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/data/history_export.dart';
import 'package:rewiremind/models/habit_log.dart';
import 'package:rewiremind/state/app_state.dart';

import 'helpers.dart';

/// An Excel export has to be enough to put a whole history back: habits,
/// every check-in, notes, the challenge — and so the streaks and calendar,
/// which are worked out from the check-ins.
void main() {
  test('an Excel export imports back to the same app', () async {
    final before = await seededState();
    await keepDay(before, before.today);
    await before.startChallenge();
    final habit = before.habits.first;
    await before.addNote(habit, before.today, 'Felt easy today');
    final photo = Uint8List.fromList(List.generate(4000, (i) => i % 251));

    final xlsx = HistoryExport.excel(before, photo: photo);

    // Somewhere else entirely: a fresh install.
    final after = await emptyState();
    final raw = HistoryExport.backupFrom(xlsx);
    expect(raw, isNotNull, reason: 'the backup sheet must read back');
    final backup = AppState.inspectBackup(raw!);
    expect(backup, isNotNull);
    expect(backup!.habits, before.everyHabit.length);
    expect(base64Decode(backup.json['photo'] as String), photo);

    await after.restoreBackup(backup);

    String habitLine(h) =>
        '${h.id} ${h.name} ${h.target} ${h.kind} ${h.colorValue} '
        '${(h.activeWeekdays.toList()..sort()).join(',')} ${h.startDay}';
    expect(
      after.everyHabit.map(habitLine).toList(),
      before.everyHabit.map(habitLine).toList(),
    );
    expect(after.perfectStreak, before.perfectStreak);
    expect(after.currentStreak, before.currentStreak);
    expect(after.challengeStartedOn, before.challengeStartedOn);
    expect(after.challengeDay, before.challengeDay);
    expect(after.notesFor(habit.id).map((n) => n.text), ['Felt easy today']);

    // Every calendar day reads the same, back to the very first.
    for (
      var day = before.firstTrackedDay;
      !day.isAfter(before.today);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      expect(after.dayStatus(day), before.dayStatus(day), reason: dayKey(day));
      for (final h in before.everyHabit) {
        expect(
          after.valueOf(h.id, day),
          before.valueOf(h.id, day),
          reason: '${h.name} on ${dayKey(day)}',
        );
      }
    }
  });

  test('a file without the backup sheet is turned away', () async {
    expect(HistoryExport.backupFrom(Uint8List.fromList([1, 2, 3])), isNull);
    // A PDF is not a workbook at all.
    expect(
      HistoryExport.backupFrom(Uint8List.fromList(utf8.encode('%PDF-1.4'))),
      isNull,
    );
  });
}
