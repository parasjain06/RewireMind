import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../state/app_state.dart';
import '../theme/habit_shade.dart';
import '../content/journal_content.dart';

/// Everything the app knows about somebody's habits, as a file they can keep.
///
/// Two formats from one set of rows, so the spreadsheet and the report never
/// disagree about what happened on a day: a spreadsheet to sort and filter,
/// and a PDF to read, print, or send to somebody.
///
/// It covers every day from the first one tracked to today — each habit that
/// was due, what was logged, whether it counted, and anything written about
/// it — plus the habits themselves and the numbers the app shows. Nothing is
/// sampled or summarised away.
class HistoryExport {
  const HistoryExport._();

  // -- the rows --------------------------------------------------------------

  /// Every habit-day worth a line: due that day, or logged even though it
  /// was not. Oldest first, habits in their display order within a day.
  static List<ExportDay> days(AppState state) {
    final out = <ExportDay>[];
    final habits = state.everyHabit;
    if (habits.isEmpty) return out;

    for (
      var day = state.firstTrackedDay;
      !day.isAfter(state.today);
      day = day.add(const Duration(days: 1))
    ) {
      for (final habit in habits) {
        final value = state.valueOf(habit.id, day);
        final due = habit.isActiveOnDay(day);
        if (!due && value <= 0) continue;
        out.add(
          ExportDay(
            day: day,
            habit: habit,
            value: value,
            due: due,
            fraction: doneFraction(habit, value),
            complete: state.isComplete(habit, day),
            notes: state.notesOn(habit.id, day),
          ),
        );
      }
    }
    return out;
  }

  /// The headline numbers, as label and value.
  static List<(String, String)> summary(AppState state) {
    final habits = state.everyHabit;
    final tracked = habits.isEmpty
        ? 0
        : state.today.difference(state.firstTrackedDay).inDays + 1;
    return [
      ('Name', state.profile.name),
      ('Exported', DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())),
      if (habits.isNotEmpty)
        ('First day tracked', _long(state.firstTrackedDay)),
      ('Days tracked', '$tracked'),
      ('Habits being tracked', '${state.habits.length}'),
      ('Habits stopped', '${habits.where((h) => h.isArchived).length}'),
      ('Current streak', _days(state.currentStreak)),
      ('Best streak', _days(state.bestStreak)),
      ('Perfect days', '${state.perfectDays}'),
      (
        '21-day challenge',
        state.challengeLive
            ? 'Day ${state.challengeDay} of $kChallengeLength'
            : 'Not started',
      ),
      ('Notes written', '${state.noteCount}'),
    ];
  }

  // -- Excel -----------------------------------------------------------------

  /// A workbook: Summary, Habits, Daily log, Calendar and Notes sheets.
  static Uint8List excel(AppState state, {Uint8List? photo}) {
    final book = xl.Excel.createExcel();
    final rows = days(state);
    final habits = state.everyHabit;

    // The workbook starts with a "Sheet1"; renaming it keeps the first tab
    // the one that opens.
    book.rename(book.getDefaultSheet() ?? 'Sheet1', 'Summary');
    final summarySheet = book['Summary'];
    _header(summarySheet, ['What', 'Value']);
    for (final (label, value) in summary(state)) {
      summarySheet.appendRow([
        xl.TextCellValue(label),
        xl.TextCellValue(value),
      ]);
    }
    summarySheet.setColumnWidth(0, 24);
    summarySheet.setColumnWidth(1, 30);

    final habitSheet = book['Habits'];
    _header(habitSheet, [
      'Habit',
      'Type',
      'Daily goal',
      'Days',
      'Started',
      'Status',
    ]);
    for (final h in habits) {
      habitSheet.appendRow([
        xl.TextCellValue(h.name),
        xl.TextCellValue(_kind(h)),
        xl.TextCellValue(_goal(h)),
        xl.TextCellValue(_schedule(h)),
        xl.TextCellValue(_long(h.startDay)),
        xl.TextCellValue(
          h.isArchived ? 'Stopped ${_long(h.archivedAt!)}' : 'Tracking',
        ),
      ]);
    }
    for (final (i, w) in [28.0, 11.0, 14.0, 26.0, 16.0, 22.0].indexed) {
      habitSheet.setColumnWidth(i, w);
    }

    final log = book['Daily log'];
    _header(log, [
      'Date',
      'Day',
      'Habit',
      'Logged',
      'Goal',
      'Unit',
      'Done %',
      'Result',
      'Notes',
    ]);
    for (final r in rows) {
      log.appendRow([
        xl.DateCellValue(year: r.day.year, month: r.day.month, day: r.day.day),
        xl.TextCellValue(DateFormat('EEE').format(r.day)),
        xl.TextCellValue(r.habit.name),
        xl.DoubleCellValue(r.value),
        xl.DoubleCellValue(r.habit.target),
        xl.TextCellValue(r.habit.unit),
        xl.IntCellValue((r.fraction * 100).round()),
        xl.TextCellValue(r.result),
        xl.TextCellValue(r.notes.join(' | ')),
      ]);
    }
    for (final (i, w) in [
      12.0,
      6.0,
      26.0,
      9.0,
      8.0,
      10.0,
      9.0,
      11.0,
      50.0,
    ].indexed) {
      log.setColumnWidth(i, w);
    }

    // The same as the calendar in the app: a row a day, a column a habit.
    final grid = book['Calendar'];
    _header(grid, ['Date', for (final h in habits) h.name]);
    final byDay = <String, Map<String, ExportDay>>{};
    for (final r in rows) {
      (byDay[dayKey(r.day)] ??= {})[r.habit.id] = r;
    }
    if (habits.isNotEmpty) {
      for (
        var day = state.firstTrackedDay;
        !day.isAfter(state.today);
        day = day.add(const Duration(days: 1))
      ) {
        final entries = byDay[dayKey(day)] ?? const {};
        grid.appendRow([
          xl.DateCellValue(year: day.year, month: day.month, day: day.day),
          for (final h in habits) xl.TextCellValue(_cell(entries[h.id])),
        ]);
      }
    }
    grid.setColumnWidth(0, 12);
    for (var i = 1; i <= habits.length; i++) {
      grid.setColumnWidth(i, 14);
    }

    final notes = book['Notes'];
    _header(notes, ['Date', 'Habit', 'Note']);
    for (final r in rows) {
      for (final note in r.notes) {
        notes.appendRow([
          xl.DateCellValue(
            year: r.day.year,
            month: r.day.month,
            day: r.day.day,
          ),
          xl.TextCellValue(r.habit.name),
          xl.TextCellValue(note),
        ]);
      }
    }
    notes.setColumnWidth(0, 12);
    notes.setColumnWidth(1, 26);
    notes.setColumnWidth(2, 70);

    // The journal, one row an entry.
    final journal = book['Journal'];
    _header(journal, ['Date', 'Mood', 'Feelings', 'Type', 'Entry']);
    for (final e in state.journal.reversed) {
      journal.appendRow([
        xl.TextCellValue(_long(e.day)),
        xl.TextCellValue(
          e.mood == null
              ? ''
              : '${e.mood} · ${JournalContent.mood(e.mood!).label}',
        ),
        xl.TextCellValue(e.feelings.map(JournalContent.feeling).join(', ')),
        xl.TextCellValue(JournalContent.template(e.template).name),
        xl.TextCellValue(e.lines.join('\n')),
      ]);
    }
    for (final (i, w) in [16.0, 12.0, 26.0, 18.0, 70.0].indexed) {
      journal.setColumnWidth(i, w);
    }

    // Last, the whole of the app's data, for Import. The sheets above are for
    // reading; this one is for putting it all back — every habit with its
    // settings, every check-in and note, the challenge and the photo. The
    // streaks and calendar come back because they are worked out from the
    // check-ins. Split across cells: Excel holds at most 32,767 characters in
    // one.
    final backup = book[backupSheet];
    backup.appendRow([xl.TextCellValue(_backupNote)]);
    backup.appendRow([xl.TextCellValue(backupMarker)]);
    final json = jsonEncode({
      ...state.exportAll(),
      if (photo != null) 'photo': base64Encode(photo),
    });
    for (var at = 0; at < json.length; at += _chunk) {
      final end = at + _chunk < json.length ? at + _chunk : json.length;
      backup.appendRow([xl.TextCellValue(json.substring(at, end))]);
    }
    backup.setColumnWidth(0, 60);

    book.setDefaultSheet('Summary');
    return Uint8List.fromList(book.save() ?? const <int>[]);
  }

  /// The sheet Import reads, and the line that says it is one.
  static const String backupSheet = 'Backup (for import)';
  static const String backupMarker = 'rewiremind-backup-v1';
  static const String _backupNote =
      'Used by Import in the RewireMind app. Please do not edit this sheet.';
  static const int _chunk = 30000;

  /// The app's data out of an Excel file this app exported, or null when the
  /// file is not one — a PDF, a spreadsheet from elsewhere, or an export
  /// from before import existed.
  static String? backupFrom(Uint8List bytes) {
    try {
      final book = xl.Excel.decodeBytes(bytes);
      final sheet = book.tables[backupSheet];
      if (sheet == null || sheet.maxRows < 3) return null;
      String text(int row) {
        final value = sheet.rows[row].isEmpty
            ? null
            : sheet.rows[row].first?.value;
        return value is xl.TextCellValue ? value.value.text ?? '' : '';
      }

      if (text(1) != backupMarker) return null;
      final json = StringBuffer();
      for (var row = 2; row < sheet.maxRows; row++) {
        json.write(text(row));
      }
      return json.toString();
    } catch (_) {
      return null;
    }
  }

  static void _header(xl.Sheet sheet, List<String> titles) {
    sheet.appendRow([for (final t in titles) xl.TextCellValue(t)]);
    final row = sheet.maxRows - 1;
    for (var c = 0; c < titles.length; c++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#E3F2E6'),
      );
    }
  }

  // -- PDF -------------------------------------------------------------------

  /// A report: the person and their numbers, the habits, a month-by-month
  /// calendar of every day, and every note.
  static Future<Uint8List> pdf(
    AppState state, {
    required ByteData regular,
    required ByteData bold,
    Uint8List? photo,
  }) async {
    final rows = days(state);
    final habits = state.everyHabit;
    final ink = PdfColor.fromHex('#1F3B2C');
    final soft = PdfColor.fromHex('#5B6B61');
    final doc = pw.Document(
      title: 'RewireMind history',
      author: state.profile.name,
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      ),
    );

    final byDay = <String, Map<String, ExportDay>>{};
    for (final r in rows) {
      (byDay[dayKey(r.day)] ??= {})[r.habit.id] = r;
    }

    // Months, oldest first, from the first day tracked to this one.
    final months = <DateTime>[];
    if (habits.isNotEmpty) {
      var m = DateTime(state.firstTrackedDay.year, state.firstTrackedDay.month);
      final last = DateTime(state.today.year, state.today.month);
      while (!m.isAfter(last)) {
        months.add(m);
        m = DateTime(m.year, m.month + 1);
      }
    }

    pw.Widget heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: ink,
        ),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'RewireMind  ·  page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: soft),
          ),
        ),
        build: (context) => [
          // The person.
          pw.Row(
            children: [
              if (photo != null)
                pw.ClipOval(
                  child: pw.Image(
                    pw.MemoryImage(photo),
                    width: 64,
                    height: 64,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              if (photo != null) pw.SizedBox(width: 14),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    state.profile.name,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  pw.Text(
                    state.profile.personalQuote,
                    style: pw.TextStyle(fontSize: 11, color: soft),
                  ),
                  pw.Text(
                    'Habit history, exported '
                    '${DateFormat('d MMMM yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 9, color: soft),
                  ),
                ],
              ),
            ],
          ),

          heading('Summary'),
          pw.TableHelper.fromTextArray(
            data: [
              for (final (label, value) in summary(state)) [label, value],
            ],
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(160),
              1: const pw.FlexColumnWidth(),
            },
          ),

          heading('Habits'),
          if (habits.isEmpty)
            pw.Text('No habits yet.')
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Habit',
                'Type',
                'Daily goal',
                'Days',
                'Started',
                'Status',
              ],
              data: [
                for (final h in habits)
                  [
                    h.name,
                    _kind(h),
                    _goal(h),
                    _schedule(h),
                    _long(h.startDay),
                    h.isArchived ? 'Stopped' : 'Tracking',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E3F2E6'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),

          // The calendar: a table a month, a row a day, a column a habit.
          for (final month in months) ...[
            heading(DateFormat('MMMM yyyy').format(month)),
            _monthTable(month, state, habits, byDay, ink),
          ],

          heading('Notes'),
          if (rows.every((r) => r.notes.isEmpty))
            pw.Text('No notes written.', style: pw.TextStyle(color: soft))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Habit', 'Note'],
              data: [
                for (final r in rows.reversed)
                  for (final note in r.notes)
                    [
                      DateFormat('d MMM yyyy').format(r.day),
                      r.habit.name,
                      note,
                    ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E3F2E6'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FixedColumnWidth(150),
                2: const pw.FlexColumnWidth(),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _monthTable(
    DateTime month,
    AppState state,
    List<Habit> habits,
    Map<String, Map<String, ExportDay>> byDay,
    PdfColor ink,
  ) {
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final start = first.isBefore(state.firstTrackedDay)
        ? state.firstTrackedDay
        : first;
    final end = last.isAfter(state.today) ? state.today : last;

    final dates = <DateTime>[
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1)))
        d,
    ];

    return pw.TableHelper.fromTextArray(
      headers: ['Date', for (final h in habits) h.name],
      data: [
        for (final d in dates)
          [
            DateFormat('EEE d').format(d),
            for (final h in habits) _cell(byDay[dayKey(d)]?[h.id]),
          ],
      ],
      headerStyle: pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: ink,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E3F2E6')),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellAlignment: pw.Alignment.center,
      cellHeight: 13,
      columnWidths: {0: const pw.FixedColumnWidth(46)},
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      // The colour says it before the words do: green kept, amber part-way,
      // pink missed, and blank where the habit was not due.
      cellDecoration: (index, data, row) {
        if (index == 0 || row == 0) return const pw.BoxDecoration();
        final text = data.toString();
        final colour = switch (text) {
          'Done' => '#CDEFD6',
          '' || '-' => '#FFFFFF',
          'Missed' => '#FBE0E0',
          _ => '#FFF1C9',
        };
        return pw.BoxDecoration(color: PdfColor.fromHex(colour));
      },
    );
  }

  // -- words -----------------------------------------------------------------

  /// What a habit-day reads as in a calendar cell.
  static String _cell(ExportDay? r) {
    if (r == null) return '';
    if (r.complete) return 'Done';
    if (!r.due) return '-';
    if (r.value <= 0) return 'Missed';
    return '${(r.fraction * 100).round()}%';
  }

  static String _kind(Habit h) =>
      h.kind == HabitKind.quit ? 'Cut back' : 'Build';

  static String _goal(Habit h) {
    if (h.target <= 1 && h.unit.isEmpty) return 'Just do it';
    final t = h.target == h.target.roundToDouble()
        ? h.target.toInt().toString()
        : h.target.toString();
    return h.unit.isEmpty ? t : '$t ${h.unit}';
  }

  static String _schedule(Habit h) {
    if (h.activeWeekdays.length == 7) return 'Every day';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = h.activeWeekdays.toList()..sort();
    return days.map((d) => names[d - 1]).join(', ');
  }

  static String _long(DateTime d) => DateFormat('d MMM yyyy').format(d);

  static String _days(int n) => n == 1 ? '1 day' : '$n days';
}

/// One habit on one day, as it goes into the files.
class ExportDay {
  const ExportDay({
    required this.day,
    required this.habit,
    required this.value,
    required this.due,
    required this.fraction,
    required this.complete,
    required this.notes,
  });

  final DateTime day;
  final Habit habit;
  final double value;

  /// Whether the habit was scheduled that day.
  final bool due;

  final double fraction;
  final bool complete;
  final List<String> notes;

  String get result {
    if (complete) return 'Done';
    if (!due) return 'Extra';
    if (value <= 0) return 'Missed';
    return 'Partial';
  }
}
