import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_data.dart';
import '../data/billing.dart';
import '../data/storage.dart';
import '../content/app_content.dart';
import '../content/notification_content.dart';
import '../models/day_phase.dart';
import '../models/habit_note.dart';
import '../models/journal_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/notification_prefs.dart';
import '../models/reminder.dart';
import '../models/premium.dart';
import '../models/progress_range.dart';
import '../models/stats.dart';
import '../models/user_profile.dart';
import '../notifications/notification_planner.dart';
import '../notifications/home_widget_service.dart';
import '../notifications/widget_views.dart';
import '../notifications/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/habit_shade.dart';

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// Sunday of the week containing [d].
DateTime endOfWeek(DateTime d) => startOfWeek(d).add(const Duration(days: 6));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// How often the clock is re-checked so the page can roll over into the next
/// time of day while the app is open.
///
/// Tests set this to null: a repeating timer never lets `pumpAndSettle`
/// finish.
Duration? livePhaseTick = const Duration(minutes: 1);

/// What a backup file says it holds, checked before anything is replaced.
class BackupSummary {
  const BackupSummary({
    required this.habits,
    required this.checkIns,
    required this.takenAt,
    required this.name,
    required this.json,
  });

  final int habits;
  final int checkIns;

  /// When the backup was made, where the file recorded it.
  final DateTime? takenAt;

  /// Whose it is, so restoring somebody else's is at least visible.
  final String? name;

  /// The parsed file, carried through so it is only decoded once.
  final Map<String, dynamic> json;
}

/// Owns all habit data and derives every statistic the screens display.
/// How many days the challenge runs for.
///
/// Lives here rather than beside the path it is drawn on: the count, the
/// widget's chip and the profile's progress bar all need it, and only one of
/// those is a screen.
const int kChallengeLength = 21;

class AppState extends ChangeNotifier {
  AppState(this._storage, {NotificationService? notifications})
    : _notifications = notifications ?? NotificationService();

  final RewireMindStorage _storage;
  final NotificationService _notifications;
  static const _planner = NotificationPlanner();
  final HomeWidgetService _widget = HomeWidgetService();

  /// What the home screen widget was last told. Read by the tests.
  HomeWidgetService get homeWidget => _widget;
  static const _uuid = Uuid();

  List<Habit> _habits = const [];
  Map<String, Map<String, double>> _logs = {};
  Map<String, Map<String, List<String>>> _notes = {};
  List<JournalEntry> _journal = [];
  UserProfile _profile = UserProfile.empty;
  PremiumStatus _premium = PremiumStatus.free;
  RewireMindTheme _theme = RewireMindTheme.forest;
  bool _loading = true;

  /// Bumped on every mutation so cached range stats are recomputed.
  int _revision = 0;
  final Map<String, _CachedStats> _statsCache = {};

  // Derived values are read inside per-day loops and by all four tabs at once
  // (the shell keeps them alive in an IndexedStack), so they are memoised and
  // invalidated together in [_bump].
  List<Habit>? _activeHabits;
  List<Habit>? _sorted;
  DateTime? _firstDay;
  int? _currentStreak;
  int? _bestStreak;
  int? _perfectDays;
  int? _perfectStreak;

  // -- time of day ----------------------------------------------------------

  /// The time of day the user has pinned in Appearance, saved between runs.
  ///
  /// One override rather than two. There used to be a transient one as well,
  /// driven by a chip on the header, but Appearance does the job properly and
  /// keeping both meant every reader had to work out which of them won.
  DayPhase? _fixedPhase;

  /// The phase every screen is painted for.
  DayPhase get activePhase => kLiveDayTheme
      ? (_fixedPhase ?? DayPhase.of(DateTime.now()))
      : kStaticPhase;

  /// The pinned time of day, or null while the app is following the clock.
  DayPhase? get fixedPhase => _fixedPhase;

  /// True when the palette is coming from the clock rather than a choice.
  bool get followsClock => _fixedPhase == null;

  /// Pins the time of day, or hands it back to the clock with null.
  Future<void> setFixedPhase(DayPhase? phase) async {
    if (_fixedPhase == phase) return;
    _fixedPhase = phase;
    await _storage.saveFixedPhase(phase?.name);
    notifyListeners();
    // The widget paints the same sky the app does, and it is the one thing on
    // screen when this screen is not. Repainting the app and leaving last
    // night behind on the home screen is how you get two answers to what time
    // of day it is.
    unawaited(refreshHomeWidget());
  }

  StreamSubscription<NotificationTap>? _notificationActions;
  NotificationPrefs _notifyPrefs = const NotificationPrefs();

  DayPhase? _themedFor;
  RewireMindTheme? _phased;
  Timer? _phaseTimer;

  // -- lifecycle ------------------------------------------------------------

  Future<void> load() async {
    final now = DateTime.now();
    _habits = _storage.loadHabits();
    _logs = _storage.loadLogs();
    _notes = _storage.loadNotes();
    _journal = _storage.loadJournal();
    _profile = _storage.loadProfile() ?? UserProfile.empty;
    _premium = _storage.loadPremium();
    _theme = RewireMindTheme.byId(_storage.loadThemeId() ?? 'forest');
    _notifyPrefs = _storage.loadNotificationPrefs();

    final pinned = _storage.loadFixedPhase();
    if (pinned != null) {
      for (final p in DayPhase.values) {
        if (p.name == pinned) _fixedPhase = p;
      }
    }

    if (!_storage.isSeeded && _habits.isEmpty) {
      if (seedDemoData) {
        _habits = seedHabits(now);
        _logs = seedLogs(_habits, now);
        await _storage.saveHabits(_habits);
        await _storage.saveLogs(_logs);
      }
      await _storage.saveProfile(_profile);
      await _storage.markSeeded();
    }

    // Same review convenience as `?tab=` on the shell: lets a time of day be
    // opened directly in the web preview. Empty on a real device, and never
    // written back to storage — it is a way of looking, not a choice.
    final wanted = Uri.base.queryParameters['phase'];
    if (wanted != null) {
      for (final p in DayPhase.values) {
        if (p.name == wanted) _fixedPhase = p;
      }
    }

    _loading = false;
    await settleChallenge();
    unawaited(refreshHomeWidget());
    _startPhaseTicker();
    _listenForNotificationActions();
    _bump();
  }

  /// Repaints the app when the clock crosses into the next phase. Cheap: it
  /// only notifies on an actual change, so a quiet hour costs nothing.
  void _startPhaseTicker() {
    final tick = livePhaseTick;
    if (tick == null || !kLiveDayTheme) return;
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(tick, (_) {
      // Midnight, with the app left open: yesterday is over now, and if it
      // was missed the challenge restarts.
      if (challengeLive && _settledOn != today) unawaited(settleChallenge());
      if (!followsClock) return;
      if (DayPhase.of(DateTime.now()) == _themedFor) return;
      notifyListeners();
      // Same again for the crossing the clock makes on its own. Without this
      // the widget keeps last night's sky until something else happens to
      // touch the habit data — which, first thing in the morning, is exactly
      // the moment nothing has.
      unawaited(refreshHomeWidget());
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _notificationActions?.cancel();
    _notifications.dispose();
    super.dispose();
  }

  void _bump() {
    _revision++;
    _statsCache.clear();
    _activeHabits = null;
    _sorted = null;
    _firstDay = null;
    _currentStreak = null;
    _bestStreak = null;
    _perfectDays = null;
    _perfectStreak = null;
    _rampIndex = null;
    notifyListeners();

    // Habit data just changed, so the pending reminders may now be chasing
    // something already done. Rebuilding them here — rather than at each
    // call site — is what guarantees a stale nudge never arrives.
    unawaited(rescheduleNotifications());
    // Same reasoning for the home screen: a widget that still says "got a
    // minute?" an hour after the day was finished is worse than no widget.
    unawaited(refreshHomeWidget());
    // And the challenge, which a change to an earlier day can break.
    if (!_loading) unawaited(settleChallenge());
  }

  // -- journal --------------------------------------------------------------

  /// Every entry, newest first.
  List<JournalEntry> get journal => _journal.toList()
    ..sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
    });

  /// The entries about [day], newest first.
  List<JournalEntry> journalOn(DateTime day) {
    final d = dateOnly(day);
    return [
      for (final e in journal)
        if (e.day == d) e,
    ];
  }

  /// The day's mood: the latest entry about it that has one.
  int? moodOn(DateTime day) {
    for (final e in journalOn(day)) {
      if (e.mood != null) return e.mood;
    }
    return null;
  }

  /// Adds [entry], or replaces the one with its id.
  Future<void> saveJournalEntry(JournalEntry entry) async {
    final at = _journal.indexWhere((e) => e.id == entry.id);
    _journal = [..._journal];
    at == -1 ? _journal.add(entry) : _journal[at] = entry;
    await _storage.saveJournal(_journal);
    notifyListeners();
  }

  /// Removes an entry, returning it so it can be put back.
  Future<JournalEntry?> deleteJournalEntry(String id) async {
    final at = _journal.indexWhere((e) => e.id == id);
    if (at == -1) return null;
    final gone = _journal[at];
    _journal = [..._journal]..removeAt(at);
    await _storage.saveJournal(_journal);
    notifyListeners();
    return gone;
  }

  /// A mood from one tap, with no words: today's check-in, or the mood of
  /// today's latest entry when there is one already.
  Future<JournalEntry> checkIn(int mood, {DateTime? day}) async {
    final d = dateOnly(day ?? today);
    final now = DateTime.now();
    final existing = journalOn(d);
    final entry = existing.isNotEmpty
        ? existing.first.copyWith(mood: mood, updatedAt: now)
        : JournalEntry(
            id: _uuid.v4(),
            day: d,
            createdAt: now,
            updatedAt: now,
            template: 'checkin',
            mood: mood,
          );
    await saveJournalEntry(entry);
    return entry;
  }

  /// Six weeks of made-up check-ins, for looking at the journal with
  /// something in it. The mood follows how much of each day was done, so the
  /// insights have a real pattern to find. Test app only.
  Future<void> seedDemoJournal() async {
    const lines = [
      ('win', 'Finished everything before lunch.'),
      ('win', 'Walked instead of scrolling.'),
      ('hard', 'Late night, slow start.'),
      ('tomorrow', 'Phone in the other room.'),
      ('good1', 'Long call with an old friend.'),
      ('text', 'Felt the habit take less effort today.'),
      ('grateful', 'A quiet morning coffee.'),
    ];
    final entries = <JournalEntry>[];
    for (var back = 42; back >= 1; back--) {
      if (back % 5 == 3) continue; // a few days skipped, as in real life
      final day = DateTime(today.year, today.month, today.day - back);
      final due = scheduledOn(day);
      final done = due.where((h) => isComplete(h, day)).length;
      final share = due.isEmpty ? 0.5 : done / due.length;
      final mood = (1.6 + share * 3.2 + ((back * 7) % 3 - 1) * 0.4)
          .round()
          .clamp(1, 5);
      final at = DateTime(day.year, day.month, day.day, 21);
      final (key, text) = lines[back % lines.length];
      entries.add(
        JournalEntry(
          id: _uuid.v4(),
          day: day,
          createdAt: at,
          updatedAt: at,
          template: back % 3 == 0 ? 'checkin' : 'evening',
          mood: mood,
          feelings: mood >= 4
              ? ['proud', if (back.isEven) 'calm' else 'motivated']
              : mood <= 2
              ? ['tired', if (back.isEven) 'stressed']
              : ['focused'],
          answers: back % 3 == 0 ? const {} : {key: text},
        ),
      );
    }
    _journal = [..._journal, ...entries];
    await _storage.saveJournal(_journal);
    notifyListeners();
  }

  /// A new, empty entry for [day] against [template], not yet saved.
  JournalEntry draftJournalEntry(String template, {DateTime? day}) {
    final now = DateTime.now();
    return JournalEntry(
      id: _uuid.v4(),
      day: dateOnly(day ?? today),
      createdAt: now,
      updatedAt: now,
      template: template,
    );
  }

  // -- basic getters --------------------------------------------------------

  bool get isLoading => _loading;
  UserProfile get profile => _profile;

  /// The active theme, already retinted for the time of day.
  ///
  /// Every screen reads this one value, which is why the whole page — header,
  /// cards, nav bar and all — changes together rather than just the artwork.
  /// Cached per phase so a rebuild does not re-derive the palette.
  RewireMindTheme get theme {
    final phase = activePhase;
    if (_phased == null || _themedFor != phase) {
      _themedFor = phase;
      _phased = _theme.forPhase(phase);
    }
    return _phased!;
  }

  /// The theme before the time of day is applied.
  RewireMindTheme get baseTheme => _theme;

  /// Habits still being tracked, in display order.
  ///
  /// Cached: this is read inside per-day loops, and re-filtering plus
  /// re-sorting on every call was enough to stall the UI thread.
  List<Habit> get habits =>
      _activeHabits ??= (_habits.where((h) => !h.isArchived).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  /// Everything ever tracked, running or discontinued, in display order.
  List<Habit> get everyHabit =>
      _sorted ??= (_habits.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  /// Habits whose lifetime overlaps [start]..[end] — what the Calendar week
  /// table and the Progress breakdown list, so a discontinued habit still
  /// appears for the period it was actually running.
  List<Habit> habitsInRange(DateTime start, DateTime end) {
    final from = dateOnly(start);
    final to = dateOnly(end);
    return everyHabit.where((h) {
      if (h.startDay.isAfter(to)) return false;
      final endDay = h.endDay;
      if (endDay != null && endDay.isBefore(from)) return false;
      return true;
    }).toList();
  }

  /// Including archived — used for the "total habits tracked" stat.
  List<Habit> get allHabits => List.unmodifiable(_habits);

  DateTime get today => dateOnly(DateTime.now());

  /// Earliest day any habit existed.
  DateTime get firstTrackedDay => _firstDay ??= _habits.isEmpty
      ? today
      : _habits.map((h) => h.startDay).reduce((a, b) => a.isBefore(b) ? a : b);

  // -- per-day values -------------------------------------------------------

  double valueOf(String habitId, DateTime day) =>
      _logs[habitId]?[dayKey(day)] ?? 0;

  bool isComplete(Habit habit, DateTime day) =>
      habit.target > 0 && valueOf(habit.id, day) >= habit.target;

  /// Habits actually being tracked on [day] — on-schedule and within their
  /// lifetime. Discontinued habits still appear for days they were running.
  List<Habit> scheduledOn(DateTime day) {
    final d = dateOnly(day);
    return everyHabit.where((h) => h.isActiveOnDay(d)).toList();
  }

  int completedCountOn(DateTime day) =>
      scheduledOn(day).where((h) => isComplete(h, day)).length;

  DayStatus dayStatus(DateTime day) {
    final d = dateOnly(day);
    if (d.isAfter(today)) return DayStatus.future;
    final scheduled = scheduledOn(d);
    if (scheduled.isEmpty) return DayStatus.empty;
    final done = scheduled.where((h) => isComplete(h, d)).length;
    if (done == 0) return DayStatus.none;
    if (done == scheduled.length) return DayStatus.all;
    return DayStatus.some;
  }

  // -- mutations ------------------------------------------------------------

  Future<void> setValue(Habit habit, DateTime day, double value) async {
    final d = dateOnly(day);
    // You cannot have done something you have not reached yet. Guarding here
    // rather than only in the widgets covers every route to a check-in —
    // Home, the calendar sheet, the week table and the detail screen.
    if (d.isAfter(today)) return;

    final key = dayKey(d);
    final forHabit = _logs.putIfAbsent(habit.id, () => <String, double>{});
    if (value <= 0) {
      forHabit.remove(key);
    } else {
      forHabit[key] = value;
    }
    await _storage.saveLogs(_logs);
    _bump();
  }

  /// Flips a habit between "done" and "not started" for [day].
  Future<void> toggleComplete(Habit habit, DateTime day) =>
      setValue(habit, day, isComplete(habit, day) ? 0 : habit.target);

  /// Creates a habit and returns it.
  ///
  /// [startOn] is the day it begins, and everything downstream is gated on it:
  /// a habit is only ever "scheduled" from its start date, so streaks, rates
  /// and the boards all count from there and no earlier. Defaults to now.
  /// Back-dating is offered when Home is showing an earlier day — the days in
  /// between then count as missed, which is the honest answer and the reason
  /// it is asked about rather than assumed.
  Future<Habit> addHabit({
    required String name,
    required String iconKey,
    required double target,
    required String unit,
    HabitKind kind = HabitKind.build,
    Set<int> activeWeekdays = const {1, 2, 3, 4, 5, 6, 7},
    int? colorValue,
    DateTime? startOn,
  }) async {
    final habit = Habit(
      id: _uuid.v4(),
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      target: target,
      unit: unit,
      kind: kind,
      createdAt: startOn == null ? DateTime.now() : dateOnly(startOn),
      activeWeekdays: activeWeekdays,
      sortOrder: _habits.length,
    );
    _habits = [..._habits, habit];
    await _storage.saveHabits(_habits);
    _bump();
    return habit;
  }

  // -- notes ----------------------------------------------------------------

  /// What the user wrote about this habit on this day, oldest first.
  ///
  /// Notes are per day rather than per habit — "skipped, calf still sore" is
  /// only useful attached to the day it explains — and a day can hold several,
  /// because the second thing you write about a day is usually that it
  /// changed.
  List<String> notesOn(String habitId, DateTime day) =>
      List.unmodifiable(_notes[habitId]?[dayKey(dateOnly(day))] ?? const []);

  bool hasNote(String habitId, DateTime day) =>
      notesOn(habitId, day).isNotEmpty;

  /// Every note on this habit, newest first: the latest day first, and the
  /// last thing written on a day ahead of the first.
  List<HabitNote> notesFor(String habitId) {
    final forHabit = _notes[habitId];
    if (forHabit == null) return const [];
    final out = <HabitNote>[];
    for (final e in forHabit.entries) {
      final day = DateTime.parse(e.key);
      for (var i = e.value.length - 1; i >= 0; i--) {
        out.add(HabitNote(day: day, index: i, text: e.value[i]));
      }
    }
    // Latest day first, and on a day the last one written first.
    out.sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      return byDay != 0 ? byDay : b.index.compareTo(a.index);
    });
    return out;
  }

  /// Adds a note to [day], after any already there. A blank one is ignored.
  Future<void> addNote(Habit habit, DateTime day, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _dayNotes(habit.id, day, create: true)!.add(trimmed);
    await _saveNotes();
  }

  /// Rewrites one note. Emptying it deletes it, so a note cannot be left
  /// behind as a blank line in the history.
  Future<void> editNote(
    Habit habit,
    DateTime day,
    int index,
    String text,
  ) async {
    final notes = _dayNotes(habit.id, day);
    if (notes == null || index < 0 || index >= notes.length) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await deleteNote(habit, day, index);
      return;
    }
    notes[index] = trimmed;
    await _saveNotes();
  }

  /// Removes one note and returns what it said, so it can be put back.
  Future<String?> deleteNote(Habit habit, DateTime day, int index) async {
    final notes = _dayNotes(habit.id, day);
    if (notes == null || index < 0 || index >= notes.length) return null;
    final removed = notes.removeAt(index);
    _dropEmpty(habit.id, day);
    await _saveNotes();
    return removed;
  }

  /// Puts a deleted note back where it was — the Undo on the snackbar.
  Future<void> restoreNote(
    Habit habit,
    DateTime day,
    int index,
    String text,
  ) async {
    final notes = _dayNotes(habit.id, day, create: true)!;
    notes.insert(index.clamp(0, notes.length), text);
    await _saveNotes();
  }

  List<String>? _dayNotes(String habitId, DateTime day, {bool create = false}) {
    final key = dayKey(dateOnly(day));
    if (!create) return _notes[habitId]?[key];
    return _notes
        .putIfAbsent(habitId, () => <String, List<String>>{})
        .putIfAbsent(key, () => <String>[]);
  }

  /// No empty lists left behind, so "has a note" and the history agree.
  void _dropEmpty(String habitId, DateTime day) {
    final forHabit = _notes[habitId];
    if (forHabit == null) return;
    final key = dayKey(dateOnly(day));
    if (forHabit[key]?.isEmpty ?? false) forHabit.remove(key);
    if (forHabit.isEmpty) _notes.remove(habitId);
  }

  Future<void> _saveNotes() async {
    await _storage.saveNotes(_notes);
    _bump();
  }

  // -- ordering -------------------------------------------------------------

  /// Applies an order chosen by dragging.
  ///
  /// Renumbers contiguously rather than trusting the incoming values,
  /// so an order that has drifted — duplicates from an old import, gaps
  /// left by a delete — is repaired rather than persisted.
  Future<void> reorderHabits(List<Habit> ordered) async {
    final ranks = <String, int>{
      for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
    };
    if (ranks.isEmpty) return;

    _habits = [
      for (final h in _habits)
        if (ranks.containsKey(h.id)) h.copyWith(sortOrder: ranks[h.id]) else h,
    ];
    await _storage.saveHabits(_habits);
    _bump();
  }

  /// Nudges a day's progress by [delta], clamped to 0..target.
  Future<void> adjustValue(Habit habit, DateTime day, double delta) {
    final next = (valueOf(habit.id, day) + delta).clamp(0.0, habit.target);
    return setValue(habit, day, next);
  }

  Future<void> updateHabit(Habit habit) async {
    _habits = [
      for (final h in _habits)
        if (h.id == habit.id) habit else h,
    ];
    await _storage.saveHabits(_habits);
    _bump();
  }

  /// Stops tracking a habit from today without touching its history.
  ///
  /// Preferred over [deleteHabit]: past statistics stay accurate because the
  /// habit still counts for the days it was actually running.
  Future<void> archiveHabit(Habit habit) =>
      updateHabit(habit.copyWith(archivedAt: today));

  /// Resumes a discontinued habit. The gap stays a gap — days between
  /// stopping and resuming were never scheduled, so they are not counted.
  Future<void> restoreHabit(Habit habit) =>
      updateHabit(habit.copyWith(clearArchived: true));

  /// Removes a habit and its history outright. Prefer [archiveHabit].
  Future<void> deleteHabit(Habit habit) async {
    _habits = _habits.where((h) => h.id != habit.id).toList();
    _logs.remove(habit.id);
    _notes.remove(habit.id);

    // Reminders scoped to a habit that no longer exists would never fire
    // again but would still sit in the list looking broken.
    final pruned = _notifyPrefs.removeForHabit(habit.id);
    if (pruned.reminders.length != _notifyPrefs.reminders.length) {
      _notifyPrefs = pruned;
      await _storage.saveNotificationPrefs(pruned);
    }
    await _storage.saveHabits(_habits);
    await _storage.saveLogs(_logs);
    await _storage.saveNotes(_notes);
    _bump();
  }

  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    await _storage.saveProfile(profile);
    // The tester's code works as a name too: signing in as it is the quickest
    // way into a paid copy of the app, and nobody types it by accident.
    if (PremiumStatus.isTestCode(profile.name)) {
      await unlockPremium(PremiumPlan.lifetime, source: 'code');
    }
    _bump();
  }

  Future<void> setTheme(RewireMindTheme theme) async {
    _theme = theme;
    _phased = null;
    await _storage.saveThemeId(theme.id);
    _bump();
  }

  /// Wipes all data and re-seeds a fresh install.
  Future<void> resetAll() async {
    await _storage.clear();
    _habits = const [];
    _logs = {};
    _notes = {};
    _profile = UserProfile.empty;
    _loading = true;
    await load();
  }

  /// Puts the app back as it was the moment it was installed: no habits, no
  /// name, no settings, the challenge unstarted and every first-run step
  /// still to come. For trying the first launch again without reinstalling.
  Future<void> freshInstall() async {
    await _notifications.cancelAll();
    await _storage.wipe();
    _habits = const [];
    _logs = {};
    _notes = {};
    _journal = [];
    _profile = UserProfile.empty;
    _theme = RewireMindTheme.forest;
    _notifyPrefs = const NotificationPrefs();
    _fixedPhase = null;
    _loading = true;
    await load();
  }

  /// Clears the record and keeps the person.
  ///
  /// Deliberately not [resetAll]: somebody starting over still has a name, a
  /// photo, a theme and a set of reminders they chose, and making them do all
  /// of that again is a punishment for wanting a clean page. Habits, check-ins,
  /// notes and the challenge go; everything about *them* stays.
  /// Puts the sign-in screen back, and touches nothing else.
  ///
  /// There is no session to end and no token to throw away — the gate is
  /// simply whether a name has been given — so signing out clears the name and
  /// leaves every habit, check-in and note exactly where it is. Sign back in
  /// and it is all still there. Deleting the account is the other button, and
  /// it says so.
  Future<void> signOut() async {
    await updateProfile(_profile.copyWith(name: ''));
  }

  Future<void> startOver() async {
    await _storage.saveHabits(const []);
    await _storage.saveLogs({});
    await _storage.saveNotes({});
    await _storage.setChallengeStartedOn(null);
    // And the rules go back in front of you. Starting over means starting
    // over: a challenge you have to agree to before it counts is one you
    // should have to agree to again, not one that quietly re-arms because
    // the app remembers you read something weeks ago.
    await _storage.forgetChallengeRules();
    _habits = const [];
    _logs = {};
    _notes = {};
    _bump();
    await rescheduleNotifications();
  }

  /// True until the walkthrough has been shown once.
  ///
  /// Read rather than cached: it is consulted once, on the first frame after
  /// launch, and a stale copy of it would mean either showing the tour twice
  /// or never showing it at all.
  bool get needsTutorial => !_storage.hasSeenTutorial;

  Future<void> markTutorialSeen() => _storage.markTutorialSeen();

  /// True until the challenge's rules have been read once.
  bool get needsChallengeRules => !_storage.hasSeenChallengeRules;

  /// The day the challenge was begun, or null while it has not been.
  DateTime? get challengeStartedOn => _storage.challengeStartedOn;

  bool get challengeLive => challengeStartedOn != null;

  /// How far along the path you are.
  ///
  /// The run of perfect days, but never more than the challenge has existed
  /// for. Both halves matter: miss a day and the run is zero, which is the
  /// restart the rules promise; and a run that predates the start does not
  /// count, because those days were not part of it.
  int get challengeDay {
    final start = challengeStartedOn;
    if (start == null) return 0;
    final elapsed = today.difference(dateOnly(start)).inDays + 1;
    return perfectStreak < elapsed ? perfectStreak : elapsed;
  }

  /// Which day of the challenge today is: 1 on the day it began.
  ///
  /// Not the same question as [challengeDay], and the path needs both. That
  /// one counts days *finished*; this one counts days *elapsed*. On the first
  /// morning they differ — nothing is finished yet and you are still on day
  /// one — and marking the stop after the last finished day as "here" put
  /// somebody on day two within a minute of starting.
  int get challengeElapsed {
    final start = challengeStartedOn;
    if (start == null) return 0;
    return today.difference(dateOnly(start)).inDays + 1;
  }

  /// How far up the path you have walked: the stop you are standing on.
  ///
  /// Today's stop while the run is intact — keeping yesterday is what earns
  /// today's — and days-kept the moment it is not, so a missed day cannot
  /// leave somebody standing further up the hill than they climbed.
  ///
  /// This is what the trail is drawn to. [challengeDay] still answers the
  /// other question, "how many days have you kept", which is what the header
  /// and the widget report.
  int get challengeStop {
    if (!challengeLive) return 0;
    final elapsed = challengeElapsed;
    if (elapsed > kChallengeLength) return kChallengeLength;
    // Yesterday kept, or it is the first day and there is no yesterday.
    return perfectStreak >= elapsed - 1 ? elapsed : challengeDay;
  }

  /// The last of the 21 days, counted from the start.
  DateTime? get _challengeLastDay {
    final start = challengeStartedOn;
    if (start == null) return null;
    final s = dateOnly(start);
    return DateTime(s.year, s.month, s.day + kChallengeLength - 1);
  }

  /// All 21 days kept. Nothing restarts it after that.
  bool get challengeFinished {
    final start = challengeStartedOn;
    final last = _challengeLastDay;
    if (start == null || last == null || last.isAfter(today)) return false;
    for (
      var d = dateOnly(start);
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (!isPerfectDay(d)) return false;
    }
    return true;
  }

  /// Whether [day] is a challenge day that is already over, and so locked.
  ///
  /// Once a day of the challenge has passed, it is part of the run — kept or
  /// not — and going back to change it would be rewriting the run: ticking a
  /// missed day to rescue it, or unticking a kept one. So a change to one
  /// restarts the challenge. Today is not locked: it is not over until
  /// midnight, and a mis-tap on it should cost nothing. Days before the
  /// challenge started are not part of it at all.
  bool challengeLocks(DateTime day) {
    final start = challengeStartedOn;
    if (start == null || challengeFinished) return false;
    final d = dateOnly(day);
    return !d.isBefore(dateOnly(start)) && d.isBefore(today);
  }

  /// Back to day one, today — after a locked day was changed.
  Future<void> restartChallenge() async {
    await _storage.setChallengeStartedOn(today);
    await _storage.setChallengeSeenStop(1);
    _settledOn = today;
    notifyListeners();
  }

  /// The day the challenge was last checked for a missed day.
  DateTime? _settledOn;

  /// Keeps the challenge honest about missed days: miss one and it goes
  /// back to day one.
  ///
  /// The start date moves to the day after the last missed one, so the path,
  /// the count and the arrows all agree on where you are. Before this, a
  /// missed day dropped the run to nothing while the path still stood you on
  /// the calendar's day — an arrow leading on from a stop you had not
  /// reached. Called on launch, after any change, and when the date turns
  /// over. Nothing to do once all 21 days are kept.
  Future<void> settleChallenge() async {
    final start = challengeStartedOn;
    final last = _challengeLastDay;
    if (start == null || last == null) return;
    _settledOn = today;
    if (challengeFinished) return;

    DateTime? missed;
    for (
      var d = dateOnly(start);
      d.isBefore(today) && !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (!isPerfectDay(d)) missed = d;
    }
    if (missed == null) return;

    await _storage.setChallengeStartedOn(
      DateTime(missed.year, missed.month, missed.day + 1),
    );
    // The new day one counts as arrived at, the same as starting does.
    await _storage.setChallengeSeenStop(1);
    notifyListeners();
  }

  /// The furthest stop already watched. Zero while the challenge is not run.
  int get challengeSeenStop => _storage.challengeSeenStop;

  /// Where the walk up the path should start, or null when there is nothing
  /// new to show.
  ///
  /// Null on the first day by construction — [startChallenge] records day one
  /// as seen, because arriving where you have just chosen to stand is not an
  /// arrival — and null again for the rest of a day once it has been watched.
  int? get challengeAdvanceFrom {
    if (!challengeLive) return null;
    final seen = challengeSeenStop;
    if (seen < 1) return null;
    return challengeStop > seen ? seen : null;
  }

  /// Whether the 21-day path plays its music.
  bool get challengeMusicOn => _storage.challengeMusicOn;

  Future<void> setChallengeMusicOn(bool on) async {
    await _storage.setChallengeMusicOn(on);
    notifyListeners();
  }

  /// Whether the day-closed sound has already played on the day [key].
  bool closeSoundPlayedOn(String key) => _storage.closeSoundDay == key;

  Future<void> markCloseSoundPlayed(String key) =>
      _storage.setCloseSoundDay(key);

  /// The day whose completion has already been celebrated.
  String? get celebratedDay => _storage.celebratedDay;

  /// Records that a day's completion has been celebrated, or clears it when
  /// the day stops being whole so that finishing it again plays again.
  Future<void> setCelebratedDay(String? key) => _storage.setCelebratedDay(key);

  /// Puts the challenge where it would be on the morning after day one.
  ///
  /// For looking at the once-a-day walk without waiting for a day boundary.
  /// It arranges the state and nothing else: back-dates the start by [days]
  /// and records day one as already watched, so the next launch finds a stop
  /// it has not shown yet and runs the real animation for it.
  ///
  /// Only sensible on a day that has actually been kept — the walk is gated on
  /// an unbroken run, and on a day with nothing logged it will correctly
  /// decline to celebrate anything.
  Future<void> rehearseChallengeDay({int days = 1}) async {
    // The back-dated days are made kept, too: a run with a missed day in it
    // would, rightly, restart the challenge rather than walk it.
    for (var back = days; back >= 1; back--) {
      final day = DateTime(today.year, today.month, today.day - back);
      for (final habit in scheduledOn(day)) {
        if (!isComplete(habit, day)) {
          final forHabit = _logs.putIfAbsent(habit.id, () => {});
          forHabit[dayKey(day)] = habit.target;
        }
      }
    }
    await _storage.saveLogs(_logs);
    await _storage.setChallengeStartedOn(today.subtract(Duration(days: days)));
    await _storage.setChallengeSeenStop(1);
    _settledOn = today;
    _bump();
  }

  /// Remembers that the walk to [challengeStop] has been watched.
  Future<void> markChallengeStopSeen() async {
    await _storage.setChallengeSeenStop(challengeStop);
    notifyListeners();
  }

  Future<void> startChallenge() async {
    await _storage.setChallengeStartedOn(today);
    // Day one counts as already arrived at. Without this the first launch
    // after starting would walk somebody from nowhere to the stop they are
    // looking at, which is a celebration of having pressed a button.
    await _storage.setChallengeSeenStop(challengeStop);
    notifyListeners();
  }

  Future<void> leaveChallenge() async {
    await _storage.setChallengeSeenStop(0);
    await _storage.setChallengeStartedOn(null);
    notifyListeners();
  }

  Future<void> markChallengeRulesSeen() => _storage.markChallengeRulesSeen();

  /// Which of the two Home views is showing.
  /// The day Home is showing.
  ///
  /// Not persisted and not a preference — it is where you happen to be
  /// looking, and it resets to today on every launch. It lives here rather
  /// than inside the Home screen because the add button is in the shell
  /// underneath it, and a new habit starting today is worth mentioning to
  /// somebody who is looking at last Tuesday.
  DateTime? _viewedDay;

  DateTime get viewedDay => _viewedDay ?? today;

  bool get viewingToday => viewedDay == today;

  void viewDay(DateTime? day) {
    final next = day == null || dateOnly(day) == today ? null : dateOnly(day);
    if (next == _viewedDay) return;
    _viewedDay = next;
    notifyListeners();
  }

  /// Whether the Calendar tab is showing the board rather than the
  /// overview. Remembered, because somebody who prefers one looks at it
  /// every time. (Stored under its old name from when the board was on
  /// Home, so a preference set then carries across.)
  bool get calendarShowsBoard => _storage.homeShowsBoard;

  Future<void> setCalendarShowsBoard(bool on) async {
    await _storage.setHomeShowsBoard(on);
    notifyListeners();
  }

  /// The colour a habit is drawn in on the board.
  ///
  /// Its own if it has been given one, otherwise the accent the theme hands
  /// its icon — so an existing habit that predates colours still looks like
  /// itself rather than defaulting to grey.
  Color colorFor(Habit habit) {
    if (habit.colorValue != null) return Color(habit.colorValue!);

    // Its place in the list, not its icon. The board is meant to read as one
    // gradient down the page, and an accent picked per icon gives a scatter of
    // unrelated hues instead — a green next to a blue next to an amber.
    final at = _rampIndex ??= {for (final (i, h) in habits.indexed) h.id: i};
    final index = at[habit.id] ?? 0;
    return Color(
      AppContent.habitColours[index % AppContent.habitColours.length],
    );
  }

  /// Each habit's place in the ramp, cached: `colorFor` is called once per
  /// cell and the board draws several hundred of them.
  Map<String, int>? _rampIndex;

  // -- home screen widget ---------------------------------------------------

  /// Days since anything at all was logged, counting today as zero.
  ///
  /// Not the streak: the streak is about keeping habits, this is about whether
  /// anybody has been here, and the widget's job is the second one.
  int get daysSinceSeen {
    for (var back = 0; back <= 30; back++) {
      final day = today.subtract(Duration(days: back));
      if (day.isBefore(firstTrackedDay)) break;
      for (final habit in everyHabit) {
        if (valueOf(habit.id, day) > 0) return back;
      }
    }
    return 31;
  }

  Future<void> refreshHomeWidget() async {
    final scheduled = scheduledOn(today);
    await _widget.push(
      streak: perfectStreak,
      pathLength: kChallengeLength,
      scheduledToday: scheduled.length,
      doneToday: scheduled.where((h) => isComplete(h, today)).length,
      daysSinceSeen: daysSinceSeen,
      phase: activePhase.name,
      hasHabits: everyHabit.isNotEmpty,
      // Null unless the challenge is actually running, which is what lets the
      // chip fall back to something true rather than counting a challenge
      // nobody started.
      challengeDay: challengeLive ? challengeDay : null,
      name: _profile.name.isEmpty ? null : _profile.firstName,
      followsClock: kLiveDayTheme && _fixedPhase == null,
      todayList: widgetList(),
      calendar: widgetCalendar(),
      streakDays: perfectStreak,
    );
  }

  /// The checklist widget's data: today's habits with their ticks, and the
  /// week ahead with none, so tomorrow's list is right before the app is
  /// opened tomorrow.
  String widgetList() => WidgetViews.list(
    hasHabits: everyHabit.isNotEmpty,
    days: {
      for (var i = 0; i < WidgetViews.listDays; i++)
        // Calendar days rather than 24-hour steps, which slip a day across a
        // clock change.
        DateTime(today.year, today.month, today.day + i): [
          for (final habit in scheduledOn(
            DateTime(today.year, today.month, today.day + i),
          ))
            WidgetTask(habit.name, done: i == 0 && isComplete(habit, today)),
        ],
    },
  );

  /// The week and month widgets' data: every day's status from the first of
  /// last month up to today.
  String widgetCalendar() {
    final from = WidgetViews.calendarFrom(today);
    return WidgetViews.calendar(
      from: from,
      stamp: today,
      statuses: [
        for (
          var day = from;
          !day.isAfter(today);
          day = DateTime(day.year, day.month, day.day + 1)
        )
          dayStatus(day),
      ],
    );
  }

  // -- notifications --------------------------------------------------------

  NotificationPrefs get notifyPrefs => _notifyPrefs;

  Future<void> setNotifyPrefs(NotificationPrefs prefs) async {
    _notifyPrefs = prefs;
    await _storage.saveNotificationPrefs(prefs);
    notifyListeners();
    await rescheduleNotifications();
  }

  /// Adds a reminder, or replaces the one with the same id.
  Future<void> saveReminder(Reminder reminder) =>
      setNotifyPrefs(_notifyPrefs.upsert(reminder));

  Future<void> deleteReminder(String id) =>
      setNotifyPrefs(_notifyPrefs.remove(id));

  Future<void> setCatchUpEnabled(bool on) =>
      setNotifyPrefs(_notifyPrefs.copyWith(catchUpEnabled: on));

  Future<void> setAppendQuote(bool on) =>
      setNotifyPrefs(_notifyPrefs.copyWith(appendQuote: on));

  Future<void> setHabitRemindersEnabled(bool on) =>
      setNotifyPrefs(_notifyPrefs.copyWith(habitRemindersEnabled: on));

  Future<void> setGeneralRemindersEnabled(bool on) =>
      setNotifyPrefs(_notifyPrefs.copyWith(generalEnabled: on));

  Future<void> setCatchUpTime(TimeOfDayValue time) =>
      setNotifyPrefs(_notifyPrefs.copyWith(catchUpTime: time));

  /// Turns reminders on, asking the OS for permission first.
  ///
  /// Returns false when permission was refused, leaving the preference off —
  /// a switch that reads "on" while Android silently drops every send is worse
  /// than one that stays off.
  Future<bool> enableNotifications() async {
    final granted = await _notifications.requestPermission();
    if (!granted) return false;

    // Nothing is added on the way in. The evening nudge is on by default and
    // is the one notification most people want; general reminders start off
    // and empty, for whoever goes looking for them.
    await setNotifyPrefs(_notifyPrefs.copyWith(enabled: true));
    return true;
  }

  Future<void> disableNotifications() =>
      setNotifyPrefs(_notifyPrefs.copyWith(enabled: false));

  /// Whether Android itself will let this app post a notification.
  ///
  /// Separate question from [NotificationPrefs.enabled], which is only what
  /// the app was told to do. The two can disagree — permission revoked in
  /// system settings, notifications turned off for the app, a channel muted —
  /// and when they do, the switch on the settings screen reads "on" while
  /// nothing ever arrives. Asking the system is the only way to know.
  Future<bool> systemNotificationsAllowed() => _notifications.hasPermission();

  /// Rebuilds the whole pending schedule from current data.
  ///
  /// Three days of runway, so reminders survive a weekend in which the app is
  /// never opened and nothing triggers a reschedule.
  Future<void> rescheduleNotifications() async {
    if (_loading) return;
    if (!_notifyPrefs.enabled) {
      await _notifications.cancelAll();
      return;
    }
    await _notifications.reschedule(planNotifications());
  }

  /// The sends the planner would make right now.
  List<PlannedSend> planNotifications({DateTime? from}) {
    return _planner.plan(
      prefs: _notifyPrefs,
      from: from ?? DateTime.now(),
      days: 3,
      snapshotFor: _snapshotFor,
    );
  }

  DaySnapshot _snapshotFor(DateTime day) {
    final d = dateOnly(day);
    final scheduled = scheduledOn(d);
    return DaySnapshot(
      day: d,
      scheduled: scheduled,
      // A future day has nothing logged yet by definition, so only today can
      // carry completions.
      completed: d == today
          ? {
              for (final h in scheduled)
                if (isComplete(h, d)) h.id,
            }
          : const <String>{},
      streak: currentStreak,
      name: _profile.firstName,
      challengeDay: _challengeDayOn(d),
      challengeLength: kChallengeLength,
    );
  }

  /// The challenge day a date will be, for the evening nudge, or null when no
  /// challenge is running on it.
  ///
  /// Today is today's stop. Days ahead assume today gets kept — the schedule
  /// is rebuilt every time anything changes, so a day that is not kept
  /// replaces tomorrow's wording long before tomorrow evening.
  int? _challengeDayOn(DateTime day) {
    if (!challengeLive) return null;
    final ahead = day.difference(today).inDays;
    final stop = challengeStop + ahead;
    // The last day kept, the path is walked: nothing left to nudge about.
    if (challengeStop >= kChallengeLength &&
        perfectStreak >= kChallengeLength) {
      return null;
    }
    return stop.clamp(1, kChallengeLength);
  }

  Future<void> setChallengeNudgeEnabled(bool on) =>
      setNotifyPrefs(_notifyPrefs.copyWith(challengeEnabled: on));

  /// Applies the notification's "All done" button: ticks everything still
  /// outstanding for today.
  ///
  /// Returns how many were logged, so the caller can confirm it.
  /// The shade's "All done" button arrives here. Wiring it in the state rather
  /// than the service is what keeps the service free of any knowledge of
  /// habits.
  void _listenForNotificationActions() {
    _notificationActions?.cancel();
    _notificationActions = _notifications.actions.listen((tap) async {
      final id = tap.habitId;
      if (id == null) return;
      if (tap.addsStep) await logStepFromNotification(id);
      // And then show it, whichever was pressed. A reminder is a prompt to
      // put a number in, and the number lives on the habit's own page.
      openHabitRequests.value = id;
    });
  }

  /// The habit a notification asked to be opened, for the shell to act on.
  ///
  /// A notifier rather than a route, because the state has no navigator and
  /// should not grow one.
  static final ValueNotifier<String?> openHabitRequests = ValueNotifier(null);

  /// The button on a habit reminder: adds one step of that habit — one glass,
  /// five minutes — to today, and never more than the target.
  ///
  /// One step rather than the lot. A reminder at two in the afternoon is about
  /// the glass just drunk, not about the other seven; a button that ticked the
  /// whole day would make the streak a record of things that did not happen,
  /// which is the one number this app is for. On a habit that is a single
  /// daily tick, one step is the whole of it, and the button says so.
  Future<double?> logStepFromNotification(String habitId) async {
    for (final habit in scheduledOn(today)) {
      if (habit.id != habitId) continue;
      final now = valueOf(habit.id, today);
      if (now >= habit.target) return null;
      final next = (now + habit.step).clamp(0.0, habit.target);
      await setValue(habit, today, next);
      return next;
    }
    return null;
  }

  /// Test app: posts the evening send in each of the shapes it can take —
  /// mid-challenge, its last day, a catch-up with a streak to lose and one
  /// without — so the wording can be read in the shade rather than in the
  /// code. Worded by the planner, from the real habits, so what arrives is
  /// what a real evening would bring. Returns how many were posted.
  Future<int> previewEveningSends() async {
    final due = scheduledOn(today);
    final sample = (due.isNotEmpty ? due : everyHabit).take(3).toList();
    if (sample.isEmpty) return 0;

    final prefs = _notifyPrefs.copyWith(
      enabled: true,
      catchUpEnabled: true,
      challengeEnabled: true,
    );
    // From midnight, so the evening's time is still ahead of "now".
    final midnight = DateTime(today.year, today.month, today.day);
    // Which day of the challenge, the streak, and how many are already done.
    const cases = [(3, 4, 1), (21, 20, 1), (null, 5, 0), (null, 0, 1)];

    var sent = 0;
    for (final (challengeDay, streak, done) in cases) {
      final kept = done.clamp(0, sample.length - 1);
      final sends = _planner.plan(
        prefs: prefs,
        from: midnight,
        days: 1,
        snapshotFor: (_) => DaySnapshot(
          day: today,
          scheduled: sample,
          completed: sample.take(kept).map((h) => h.id).toSet(),
          streak: streak,
          challengeDay: challengeDay,
        ),
      );
      for (final send in sends) {
        if (send.kind != SendKind.nudge) continue;
        await _notifications.showNow(send, id: 900 + sent);
        sent++;
        // Far enough apart to arrive in order, and to be heard as four.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        break;
      }
    }
    return sent;
  }

  /// Posts today's evening check-in immediately, as it will arrive. False when
  /// there is nothing to say — no habits, or the day already done.
  Future<bool> sendTestNudge() async {
    // Planned from midnight, so the evening send is still ahead of "now".
    final sends = _planner.plan(
      prefs: _notifyPrefs.copyWith(enabled: true, catchUpEnabled: true),
      from: today,
      days: 1,
      snapshotFor: _snapshotFor,
    );
    for (final send in sends) {
      if (send.kind == SendKind.nudge) {
        await _notifications.showNow(send);
        return true;
      }
    }
    return false;
  }

  /// Posts one reminder immediately, exactly as it would arrive on schedule.
  /// Returns false when there are no habits, since the tokens would resolve
  /// to nothing.
  Future<bool> sendTestNotification(Reminder reminder) async {
    final snapshot = _snapshotFor(today);
    if (snapshot.scheduled.isEmpty) return false;

    final owner = reminder.isForHabit
        ? snapshot.habitById(reminder.habitId!)
        : null;
    await _notifications.showNow(
      PlannedSend(
        reminderId: reminder.id,
        at: DateTime.now(),
        phase: activePhase,
        title: reminder.text,
        body: _notifyPrefs.appendQuote
            ? NotificationContent.quoteFor(today)
            : '',
        kind: owner != null ? SendKind.habit : SendKind.general,
        habitId: owner?.id,
        label: owner?.name,
        canMarkDone: owner != null && !snapshot.isDone(owner.id),
      ),
    );
    return true;
  }

  // -- streaks --------------------------------------------------------------

  /// Whether any scheduled habit was completed on [day].
  ///
  /// Deliberately avoids `scheduledOn`, which allocates a list per call — this
  /// runs once per day across the whole history.
  bool _showedUpOn(DateTime day) {
    for (final habit in everyHabit) {
      if (!habit.isActiveOnDay(day)) continue;
      if (isComplete(habit, day)) return true;
    }
    return false;
  }

  /// Consecutive days, ending today (or yesterday if today is still untouched),
  /// on which at least one scheduled habit was completed.
  int get currentStreak => _currentStreak ??= _computeCurrentStreak();

  int _computeCurrentStreak() {
    var cursor = today;
    if (!_showedUpOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final floor = firstTrackedDay;
    var streak = 0;
    while (!cursor.isBefore(floor) && _showedUpOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// A day where every habit that was scheduled got done.
  ///
  /// A day with nothing scheduled is not perfect — it is empty.
  bool isPerfectDay(DateTime day) {
    final d = dateOnly(day);
    if (d.isAfter(today)) return false;
    var scheduled = 0;
    for (final habit in everyHabit) {
      if (!habit.isActiveOnDay(d)) continue;
      scheduled++;
      if (!isComplete(habit, d)) return false;
    }
    return scheduled > 0;
  }

  /// Perfect days between two dates, never counting past today.
  int perfectDaysIn(DateTime start, DateTime end) {
    var count = 0;
    final stop = end.isAfter(today) ? today : end;
    for (
      var d = dateOnly(start);
      !d.isAfter(stop);
      d = d.add(const Duration(days: 1))
    ) {
      if (isPerfectDay(d)) count++;
    }
    return count;
  }

  /// Perfect days over the whole history, however scattered.
  int get perfectDays => _perfectDays ??= perfectDaysIn(firstTrackedDay, today);

  /// Consecutive perfect days ending today — the 21-day challenge.
  ///
  /// A run, not a tally. Twenty-one days is the claim the challenge makes, and
  /// the claim is about doing it *daily*: three weeks of habit with a fortnight
  /// off in the middle is not the thing being described, so a missed day puts
  /// this back to nothing.
  ///
  /// Today not being finished yet does not break it. Until midnight the day is
  /// still winnable, so an unfinished today is skipped rather than counted as a
  /// miss — otherwise the number every user sees for most of the day is zero.
  int get perfectStreak => _perfectStreak ??= _computePerfectStreak();

  int _computePerfectStreak() {
    var cursor = today;
    if (!isPerfectDay(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final floor = firstTrackedDay;
    var run = 0;
    while (!cursor.isBefore(floor) && isPerfectDay(cursor)) {
      run++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return run;
  }

  /// Longest such run over the whole history.
  int get bestStreak => _bestStreak ??= _computeBestStreak();

  int _computeBestStreak() {
    var best = 0;
    var run = 0;
    for (
      var d = firstTrackedDay;
      !d.isAfter(today);
      d = d.add(const Duration(days: 1))
    ) {
      if (_showedUpOn(d)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  /// Current streak for a single habit.
  int habitStreak(Habit habit) {
    // A discontinued habit's streak is frozen at the day it stopped.
    var cursor = habit.endDay ?? today;
    if (cursor.isAfter(today)) cursor = today;
    if (!isComplete(habit, cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final floor = habit.startDay;
    var streak = 0;
    while (!cursor.isBefore(floor)) {
      if (habit.isActiveOnDay(cursor)) {
        if (!isComplete(habit, cursor)) break;
        streak++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of consecutive *scheduled* days this habit was completed.
  /// Days the habit isn't scheduled on are skipped rather than breaking a run.
  int habitBestStreak(Habit habit) {
    var best = 0;
    var run = 0;
    for (
      var d = habit.startDay;
      !d.isAfter(today);
      d = d.add(const Duration(days: 1))
    ) {
      if (!habit.isActiveOnDay(d)) continue;
      if (isComplete(habit, d)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  /// Completed/scheduled slots for one habit between two days (inclusive,
  /// never counting past today).
  ({int completed, int scheduled}) habitTally(
    Habit habit,
    DateTime start,
    DateTime end,
  ) => _tally(start, end, only: habit);

  // -- premium ---------------------------------------------------------------

  PremiumStatus get premium => _premium;

  bool get isPremium => _premium.active;

  /// Whether another habit can be added on the free tier.
  ///
  /// Counted over the habits actually running, of either kind — five between
  /// build and cut back — so a discontinued one does not hold a place for
  /// ever.
  bool get canAddHabit => isPremium || habits.length < kFreeHabitLimit;

  /// Turns premium on for this device.
  ///
  /// Local on purpose: when a store is wired up, this is what its purchase
  /// callback calls, and the rest of the app never has to know the difference.
  Future<void> unlockPremium(
    PremiumPlan plan, {
    String source = 'store',
  }) async {
    _premium = PremiumStatus(plan: plan, since: DateTime.now(), source: source);
    await _storage.savePremium(_premium);
    notifyListeners();
  }

  /// Starts listening to the store, and asks it what this account already
  /// owns.
  ///
  /// Called once at startup. A purchase made on another phone — or on this
  /// one before the app was deleted — comes back through the same listener a
  /// fresh purchase does, so there is one path into [unlockPremium] and not
  /// two. Android replays quietly; on iOS a restore can ask for a password,
  /// so there it waits for the button on the premium page.
  Future<void> startBilling() async {
    if (!Billing.supported) return;
    Billing.instance.onOwned = (plan) => unlockPremium(plan);
    await Billing.instance.start();
    if (Platform.isAndroid) await Billing.instance.restore();
  }

  /// The tester's code. True when it was the right one.
  Future<bool> redeemPremiumCode(String code) async {
    if (!PremiumStatus.isTestCode(code)) return false;
    await unlockPremium(PremiumPlan.lifetime, source: 'code');
    return true;
  }

  /// Back to the free tier — the Test app's way of seeing what everybody else
  /// sees.
  Future<void> clearPremium() async {
    _premium = PremiumStatus.free;
    await _storage.savePremium(_premium);
    notifyListeners();
  }

  /// Lifetime tally for a habit, from the day it was created.
  ({int completed, int scheduled}) habitTotals(Habit habit) =>
      _tally(dateOnly(habit.createdAt), today, only: habit);

  /// How much of a habit has actually been done over its life, 0 to 100,
  /// counting a part-done day for the part that was done.
  ///
  /// Five pages of ten is half a day here, not a nought. The whole-day tally
  /// behind streaks and perfect days cannot say that — it only knows whether
  /// the target was reached — and a habit measured in pages or minutes spends
  /// most of its days somewhere in between, which left this reading 0% for
  /// somebody who had read every day. The board has always drawn those days
  /// in half-strength colour; this is the same number.
  int habitDonePercent(Habit habit) {
    var done = 0.0;
    var scheduled = 0;
    for (
      var d = dateOnly(habit.createdAt);
      !d.isAfter(today);
      d = d.add(const Duration(days: 1))
    ) {
      if (!habit.isActiveOnDay(d)) continue;
      scheduled++;
      done += doneFraction(habit, valueOf(habit.id, d));
    }
    return scheduled == 0 ? 0 : ((done / scheduled) * 100).round();
  }

  /// Makes [day] one the habit is tracked on, so an edit to it counts for
  /// something: its start moves back to that day.
  ///
  /// Everything else is derived from the logs and the habit's own dates, so
  /// there is nothing to recalculate by hand — the streaks, the board and the
  /// percentages all take the new start into account the moment it is saved.
  Future<void> trackHabitFrom(Habit habit, DateTime day) async {
    final d = dateOnly(day);
    if (!d.isBefore(habit.startDay)) return;
    await updateHabit(habit.copyWith(createdAt: d));
  }

  int get daysActive => today.difference(firstTrackedDay).inDays + 1;

  // -- what is actually stored ----------------------------------------------

  /// Every day of every habit that has a number against it.
  ///
  /// Counted rather than derived from the stats, because Account is answering
  /// "how much of my data is in here" — which is a question about the store,
  /// not about how well anybody is doing.
  int get checkInCount =>
      _logs.values.fold(0, (sum, days) => sum + days.length);

  /// Whether one habit has anything at all logged against it.
  ///
  /// The question behind "delete this or keep its history": a habit nobody
  /// ever ticked has nothing worth preserving, and one that was tracked for
  /// three weeks does.
  bool hasHistory(String habitId) =>
      (_logs[habitId] ?? const {}).values.any((v) => v > 0);

  /// Every day of every habit that has something written against it.
  int get noteCount => _notes.values.fold(
    0,
    (sum, days) => sum + days.values.fold(0, (n, list) => n + list.length),
  );

  /// What a backup file contains, without committing to it.
  ///
  /// Restoring replaces everything, so the screen has to be able to say what
  /// it is about to replace it *with* — and a file that turns out to be some
  /// other app's JSON has to fail here, before anything is written.
  /// Slides the bundled demo forward so its history ends on [endOn].
  ///
  /// By whole weeks, so a weekdays-only habit's check-ins stay on weekdays;
  /// the days still missing after that — never more than six — are filled
  /// with the same weekday from the week before. Returns the text unchanged
  /// if it is not a backup, or already reaches [endOn].
  ///
  /// For the demo only. A backup somebody restores is their own history and
  /// its dates are facts, not a setting.
  static String freshenDemo(String raw, DateTime endOn) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return raw;
      json = decoded;
    } on FormatException {
      return raw;
    }
    final logs = json['logs'];
    if (logs is! Map) return raw;

    DateTime? last;
    for (final days in logs.values) {
      if (days is! Map) continue;
      for (final key in days.keys) {
        final day = DateTime.tryParse(key as String);
        if (day != null && (last == null || day.isAfter(last))) last = day;
      }
    }
    final end = dateOnly(endOn);
    if (last == null || !last.isBefore(end)) return raw;

    final shift = Duration(days: end.difference(last).inDays ~/ 7 * 7);
    String moved(String key) {
      final day = DateTime.tryParse(key);
      return day == null ? key : dayKey(day.add(shift));
    }

    Map<String, dynamic> slide(Map<dynamic, dynamic> byHabit) => {
      for (final e in byHabit.entries)
        e.key as String: {
          for (final d in (e.value as Map).entries)
            moved(d.key as String): d.value,
        },
    };

    final shifted = slide(logs);
    final notes = json['notes'];
    if (notes is Map) json['notes'] = slide(notes);

    // The gap whole weeks could not close, filled from a week earlier.
    for (
      var day = dateOnly(last.add(shift)).add(const Duration(days: 1));
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      final from = dayKey(day.subtract(const Duration(days: 7)));
      for (final days in shifted.values) {
        final map = days as Map<String, dynamic>;
        if (map.containsKey(from)) map[dayKey(day)] = map[from];
      }
    }
    json['logs'] = shifted;

    for (final habit in (json['habits'] as List? ?? const [])) {
      if (habit is! Map) continue;
      for (final field in const ['createdAt', 'archivedAt']) {
        final at = DateTime.tryParse(habit[field] as String? ?? '');
        if (at != null) habit[field] = at.add(shift).toIso8601String();
      }
    }
    return jsonEncode(json);
  }

  static BackupSummary? inspectBackup(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      // Both names accepted. The app was called RewireMind when the export
      // format was written, and a rename is no reason for somebody's backup
      // to stop being readable.
      if (json['app'] != 'rewiremind') {
        return null;
      }

      final habits = json['habits'];
      final logs = json['logs'];
      if (habits is! List || logs is! Map) return null;

      var checkIns = 0;
      for (final days in logs.values) {
        if (days is Map) checkIns += days.length;
      }

      return BackupSummary(
        habits: habits.length,
        checkIns: checkIns,
        takenAt: DateTime.tryParse(json['exportedAt'] as String? ?? ''),
        name: (json['profile'] as Map?)?['name'] as String?,
        json: json,
      );
    } on FormatException {
      return null;
    }
  }

  /// Replaces everything with the contents of a backup.
  ///
  /// Whole-file, not a merge. Merging two histories of the same habit means
  /// deciding which check-in wins on a day they disagree, and there is no
  /// answer to that which is not a guess about what somebody actually did.
  Future<void> restoreBackup(BackupSummary backup) async {
    final json = backup.json;

    _habits = [
      for (final raw in json['habits'] as List)
        Habit.fromJson(raw as Map<String, dynamic>),
    ];
    _logs = {
      for (final e in (json['logs'] as Map).entries)
        e.key as String: {
          for (final d in (e.value as Map).entries)
            d.key as String: (d.value as num).toDouble(),
        },
    };
    _notes = {
      for (final e in ((json['notes'] as Map?) ?? {}).entries)
        e.key as String: {
          for (final d in (e.value as Map).entries)
            if (readDayNotes(d.value).isNotEmpty)
              d.key as String: readDayNotes(d.value),
        },
    };
    if (json['profile'] != null) {
      _profile = UserProfile.fromJson(json['profile'] as Map<String, dynamic>);
    }
    if (json['themeId'] != null) {
      _theme = RewireMindTheme.byId(json['themeId'] as String);
      _phased = null;
    }
    if (json['notifications'] != null) {
      _notifyPrefs = NotificationPrefs.fromJson(
        json['notifications'] as Map<String, dynamic>,
      );
    }

    final challenge = json['challenge'];
    if (challenge is Map) {
      final started = DateTime.tryParse(
        challenge['startedOn'] as String? ?? '',
      );
      await _storage.setChallengeStartedOn(started);
      await _storage.setChallengeSeenStop(
        (challenge['seenStop'] as num?)?.toInt() ?? 0,
      );
      if (challenge['rulesSeen'] == true) {
        await _storage.markChallengeRulesSeen();
      }
    }
    if (json.containsKey('fixedPhase')) {
      _fixedPhase = null;
      for (final p in DayPhase.values) {
        if (p.name == json['fixedPhase']) _fixedPhase = p;
      }
      await _storage.saveFixedPhase(_fixedPhase?.name);
    }

    // Older backups carry no journal; they leave the one here alone.
    if (json['journal'] is List) {
      _journal = [
        for (final raw in json['journal'] as List) ?JournalEntry.fromJson(raw),
      ];
      await _storage.saveJournal(_journal);
    }

    await _storage.saveHabits(_habits);
    await _storage.saveLogs(_logs);
    await _storage.saveNotes(_notes);
    await _storage.saveProfile(_profile);
    await _storage.saveThemeId(_theme.id);
    await _storage.saveNotificationPrefs(_notifyPrefs);
    await _storage.markSeeded();

    _bump();
  }

  /// Everything this install holds, as JSON.
  ///
  /// The same shapes that go into storage, so a copy taken here is a copy of
  /// the real thing rather than a report about it.
  Map<String, dynamic> exportAll() => {
    'app': 'rewiremind',
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': _profile.toJson(),
    'themeId': _theme.id,
    'habits': [for (final h in everyHabit) h.toJson()],
    'logs': _logs,
    'notes': _notes,
    'journal': [for (final e in _journal) e.toJson()],
    'notifications': _notifyPrefs.toJson(),
    // Streaks and calendar days are worked out from the logs, so they need
    // nothing of their own. The challenge is the one thing that is not: it
    // is a date somebody chose to start on.
    'challenge': {
      'startedOn': challengeStartedOn?.toIso8601String(),
      'seenStop': challengeSeenStop,
      'rulesSeen': !needsChallengeRules,
    },
    'fixedPhase': _fixedPhase?.name,
  };

  // -- range statistics -----------------------------------------------------

  /// Inclusive start/end of [range] as shown in the UI. The end may be in the
  /// future (the rest of the current week/month); counting stops at today.
  ({DateTime start, DateTime end}) boundsFor(ProgressRange range) {
    switch (range) {
      case ProgressRange.week:
        return (start: startOfWeek(today), end: endOfWeek(today));
      case ProgressRange.month:
        return (start: startOfMonth(today), end: endOfMonth(today));
      case ProgressRange.year:
        return (
          start: DateTime(today.year, 1, 1),
          end: DateTime(today.year, 12, 31),
        );
      case ProgressRange.allTime:
        return (start: firstTrackedDay, end: today);
    }
  }

  /// Completed/scheduled slots between [start] and [end], never past today.
  ({int completed, int scheduled}) _tally(
    DateTime start,
    DateTime end, {
    Habit? only,
  }) {
    var completed = 0;
    var scheduled = 0;
    final stop = end.isAfter(today) ? today : end;
    final list = only == null ? everyHabit : <Habit>[only];
    for (
      var d = dateOnly(start);
      !d.isAfter(stop);
      d = d.add(const Duration(days: 1))
    ) {
      for (final h in list) {
        if (!h.isActiveOnDay(d)) continue;
        scheduled++;
        if (isComplete(h, d)) completed++;
      }
    }
    return (completed: completed, scheduled: scheduled);
  }

  int _percentIn(DateTime start, DateTime end) {
    final t = _tally(start, end);
    return t.scheduled == 0 ? 0 : ((t.completed / t.scheduled) * 100).round();
  }

  /// Everything the Progress tab needs, cached per range until data changes.
  RangeStats statsFor(ProgressRange range) {
    final cached = _statsCache[range.name];
    if (cached != null && cached.revision == _revision) return cached.stats;
    final stats = _computeStats(range);
    _statsCache[range.name] = _CachedStats(_revision, stats);
    return stats;
  }

  RangeStats _computeStats(ProgressRange range) {
    final bounds = boundsFor(range);
    final tally = _tally(bounds.start, bounds.end);

    return RangeStats(
      range: range,
      completed: tally.completed,
      scheduled: tally.scheduled,
      previousPercent: _previousPercent(range),
      hasPrevious: _hasPrevious(range),
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      activeHabits: habits.length,
      totalHabits: everyHabit.length,
      daysActive: daysActive,
      perfectDays: perfectDaysIn(bounds.start, bounds.end),
      series: _seriesFor(range),
      breakdown: [
        for (final habit in habitsInRange(bounds.start, bounds.end))
          () {
            // One pass per habit; this used to run twice for the same range.
            final tally = _tally(bounds.start, bounds.end, only: habit);
            return HabitBreakdown(
              habit: habit,
              completed: tally.completed,
              scheduled: tally.scheduled,
              streak: habitStreak(habit),
            );
          }(),
      ],
    );
  }

  int _previousPercent(ProgressRange range) {
    final span = _previousSpan(range);
    return span == null ? 0 : _percentIn(span.$1, span.$2);
  }

  /// Whether the period before this one is one the user was actually here for.
  ///
  /// Somebody who started on Tuesday has no last week, and telling them they
  /// are up a hundred points on it is a compliment about nothing. The check is
  /// against the first tracked day rather than against the previous period's
  /// score, because a genuine zero — a week where they tracked and missed
  /// everything — is a real comparison worth making.
  bool _hasPrevious(ProgressRange range) {
    final span = _previousSpan(range);
    return span != null && !span.$2.isBefore(firstTrackedDay);
  }

  /// The period before [range], or null where there is no such thing.
  (DateTime, DateTime)? _previousSpan(ProgressRange range) {
    switch (range) {
      case ProgressRange.week:
        final start = startOfWeek(today).subtract(const Duration(days: 7));
        return (start, start.add(const Duration(days: 6)));
      case ProgressRange.month:
        final prev = DateTime(today.year, today.month - 1, 1);
        return (prev, endOfMonth(prev));
      case ProgressRange.year:
        return (
          DateTime(today.year - 1, 1, 1),
          DateTime(today.year - 1, 12, 31),
        );
      case ProgressRange.allTime:
        return null;
    }
  }

  List<ChartPoint> _seriesFor(ProgressRange range) {
    switch (range) {
      case ProgressRange.week:
        return _weekSeries();
      case ProgressRange.month:
        return _monthSeries();
      case ProgressRange.year:
        return _yearSeries();
      case ProgressRange.allTime:
        return _allTimeSeries();
    }
  }

  List<ChartPoint> _weekSeries() {
    final start = startOfWeek(today);
    final dayName = DateFormat('EEE');
    final dayDate = DateFormat('d MMM');
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = start.add(Duration(days: i));
          return ChartPoint(
            label: dayName.format(d),
            sublabel: dayDate.format(d),
            percent: d.isAfter(today) ? 0 : _percentIn(d, d),
            isCurrent: d == today,
            isFuture: d.isAfter(today),
          );
        }(),
    ];
  }

  List<ChartPoint> _monthSeries() {
    final start = startOfMonth(today);
    final last = endOfMonth(today);
    final weeks = last.day ~/ 7;
    final fmt = DateFormat('d');
    final monthFmt = DateFormat('MMM');
    return [
      for (var i = 0; i < weeks; i++)
        () {
          final from = DateTime(start.year, start.month, i * 7 + 1);
          final to = i == weeks - 1
              ? last
              : DateTime(start.year, start.month, (i + 1) * 7);
          return ChartPoint(
            label: 'Week ${i + 1}',
            sublabel:
                '${fmt.format(from)} – ${fmt.format(to)} ${monthFmt.format(to)}',
            percent: from.isAfter(today) ? 0 : _percentIn(from, to),
            isCurrent: !today.isBefore(from) && !today.isAfter(to),
            isFuture: from.isAfter(today),
          );
        }(),
    ];
  }

  List<ChartPoint> _yearSeries() {
    final fmt = DateFormat('MMM');
    return [
      for (var m = 1; m <= 12; m++)
        () {
          final from = DateTime(today.year, m, 1);
          final to = DateTime(today.year, m + 1, 0);
          return ChartPoint(
            label: fmt.format(from),
            percent: from.isAfter(today) ? 0 : _percentIn(from, to),
            isCurrent: m == today.month,
            isFuture: from.isAfter(today),
          );
        }(),
    ];
  }

  List<ChartPoint> _allTimeSeries() {
    final firstYear = firstTrackedDay.year;
    return [
      for (var y = firstYear; y <= today.year; y++)
        ChartPoint(
          label: '$y',
          sublabel: y == today.year ? '(so far)' : null,
          percent: _percentIn(DateTime(y, 1, 1), DateTime(y, 12, 31)),
          isCurrent: y == today.year,
        ),
    ];
  }
}

class _CachedStats {
  _CachedStats(this.revision, this.stats);

  final int revision;
  final RangeStats stats;
}
