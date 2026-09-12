import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/journal_content.dart';
import 'package:rewiremind/data/history_export.dart';
import 'package:rewiremind/journal/journal_insights.dart';
import 'package:rewiremind/models/habit.dart';
import 'package:rewiremind/models/journal_entry.dart';
import 'package:rewiremind/screens/journal_editor_screen.dart';
import 'package:rewiremind/screens/journal_screen.dart';
import 'package:rewiremind/state/app_state.dart';
import 'package:rewiremind/widgets/journal_widgets.dart';

import 'helpers.dart';

void main() {
  group('entries', () {
    test('survive a round trip through JSON', () {
      final entry = JournalEntry(
        id: 'e1',
        day: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10, 21, 5),
        updatedAt: DateTime(2026, 9, 10, 21, 9),
        template: 'evening',
        mood: 4,
        feelings: const ['proud', 'tired'],
        answers: const {'win': 'Ran 5k', 'tomorrow': 'Sleep by 11'},
      );
      final back = JournalEntry.fromJson(entry.toJson())!;
      expect(back.id, 'e1');
      expect(back.day, DateTime(2026, 9, 10));
      expect(back.mood, 4);
      expect(back.feelings, ['proud', 'tired']);
      expect(back.lines, ['Ran 5k', 'Sleep by 11']);
      expect(JournalEntry.fromJson({'nonsense': true}), isNull);
    });

    test('a tap on a face is an entry, and a second tap changes it', () async {
      final state = await seededState();
      await state.checkIn(2);
      expect(state.journalOn(state.today), hasLength(1));
      expect(state.moodOn(state.today), 2);

      await state.checkIn(5);
      expect(state.journalOn(state.today), hasLength(1), reason: 'not two');
      expect(state.moodOn(state.today), 5);
    });

    test('go out with the backup and come back with an import', () async {
      final before = await seededState();
      await before.checkIn(4);
      await before.saveJournalEntry(
        before
            .draftJournalEntry('gratitude')
            .copyWith(mood: 5, answers: {'good1': 'Sunshine'}),
      );

      final raw = HistoryExport.backupFrom(HistoryExport.excel(before))!;
      final after = await emptyState();
      await after.restoreBackup(AppState.inspectBackup(raw)!);

      expect(after.journal, hasLength(2));
      expect(after.journal.any((e) => e.lines.contains('Sunshine')), isTrue);
    });
  });

  group('insights', () {
    final walk = Habit(
      id: 'walk',
      name: 'Walk',
      iconKey: 'walk',
      target: 1,
      unit: '',
      createdAt: DateTime(2026, 1, 1),
    );

    test('a habit done on the good days shows as lifting the mood', () {
      final moods = <DateTime, int>{};
      final walked = <DateTime>{};
      for (var i = 1; i <= 8; i++) {
        final day = DateTime(2026, 9, i);
        final did = i.isEven;
        moods[day] = did ? 5 : 2;
        if (did) walked.add(day);
      }
      final lifts = JournalInsights.lift(
        moods: moods,
        habits: [walk],
        scheduled: (_, _) => true,
        done: (_, d) => walked.contains(d),
      );
      expect(lifts.single.delta, closeTo(3.0, 0.001));
      expect(lifts.single.withDays, 4);
      expect(lifts.single.withoutDays, 4);
    });

    test('too few days either way says nothing rather than guess', () {
      final lifts = JournalInsights.lift(
        moods: {DateTime(2026, 9, 1): 5, DateTime(2026, 9, 2): 1},
        habits: [walk],
        scheduled: (_, _) => true,
        done: (_, d) => d.day == 1,
      );
      expect(lifts, isEmpty);
    });

    test("the day's mood is its latest entry's", () {
      final day = DateTime(2026, 9, 5);
      JournalEntry at(int hour, int mood) => JournalEntry(
        id: '$hour',
        day: day,
        createdAt: DateTime(2026, 9, 5, hour),
        updatedAt: DateTime(2026, 9, 5, hour),
        template: 'checkin',
        mood: mood,
      );
      expect(JournalInsights.dailyMood([at(8, 2), at(21, 4)])[day], 4);
    });
  });

  testWidgets('from Home: a face, then words, saved', (tester) async {
    final state = await seededState();
    await pumpAppWith(tester, state);

    // The strip is pinned under the list: no scrolling to reach it.
    final bar = find.byType(JournalCheckInBar);
    expect(bar, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: bar,
        matching: find.byIcon(JournalContent.moods.last.icon),
      ),
    );
    await tester.pumpAndSettle();
    expect(state.moodOn(state.today), 5);

    await tester.tap(find.text(JournalContent.homeAddWords));
    await tester.pumpAndSettle();
    expect(find.byType(JournalEditorScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'A good one');
    await tester.tap(find.text(JournalContent.editorSave));
    await tester.pumpAndSettle();
    expect(state.journalOn(state.today).single.lines, ['A good one']);
    expect(state.journalOn(state.today).single.mood, 5);
    await letToastPass(tester);
  });

  testWidgets('the journal and its insights lay out', (tester) async {
    final state = await seededState();
    await state.seedDemoJournal();
    await pumpAppWith(tester, state);
    JournalScreen.open(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    expect(find.text(JournalContent.entriesTab), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(JournalContent.insightsTab));
    await tester.pumpAndSettle();
    expect(find.text(JournalContent.insightsLift), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
