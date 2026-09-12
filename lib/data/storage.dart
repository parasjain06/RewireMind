import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_note.dart';
import '../models/habit.dart';
import '../models/notification_prefs.dart';
import '../models/user_profile.dart';
import '../models/journal_entry.dart';
import '../models/premium.dart';

/// Local persistence, backed by shared_preferences.
///
/// Logs are stored in a compact nested map (`habitId -> yyyy-MM-dd -> value`)
/// rather than a flat list, which keeps years of history to a few tens of KB.
class RewireMindStorage {
  RewireMindStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _kHabits = 'habits';
  static const _kLogs = 'logs';
  static const _kNotes = 'notes';
  static const _kJournal = 'journal';
  static const _kProfile = 'profile';
  static const _kThemeId = 'themeId';
  static const _kSeeded = 'seeded';
  static const _kNotifyPrefs = 'notifyPrefs';
  static const _kFixedPhase = 'fixedPhase';
  static const _kTutorial = 'tutorialSeen';
  static const String _kChallengeMusic = 'challengeMusic';
  static const _kRules = 'challengeRulesSeen';
  static const _kChallengeStart = 'challengeStartedOn';
  static const _kChallengeSeen = 'challengeSeenStop';
  static const _kCelebrated = 'celebratedDay';
  static const _kCloseSound = 'closeSoundDay';
  static const _kBoard = 'homeShowsBoard';
  static const _kPremium = 'premium';

  static Future<RewireMindStorage> open() async =>
      RewireMindStorage(await SharedPreferences.getInstance());

  // -- habits ---------------------------------------------------------------

  List<Habit> loadHabits() {
    final raw = _prefs.getString(_kHabits);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Habit.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> saveHabits(List<Habit> habits) => _prefs.setString(
    _kHabits,
    jsonEncode(habits.map((h) => h.toJson()).toList()),
  );

  // -- logs -----------------------------------------------------------------

  /// `habitId -> { 'yyyy-MM-dd': value }`
  Map<String, Map<String, double>> loadLogs() {
    final raw = _prefs.getString(_kLogs);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: {
          for (final day in (entry.value as Map<String, dynamic>).entries)
            day.key: (day.value as num).toDouble(),
        },
    };
  }

  Future<void> saveLogs(Map<String, Map<String, double>> logs) =>
      _prefs.setString(_kLogs, jsonEncode(logs));

  // -- notes ----------------------------------------------------------------

  /// `habitId -> { 'yyyy-MM-dd': note }`, shaped like the logs so a day's
  /// note is as cheap to reach as its value.
  /// Every note, by habit and then by day. A day holds a list: see
  /// [readDayNotes], which also reads the one-string-a-day shape notes were
  /// saved in before a day could hold more than one.
  Map<String, Map<String, List<String>>> loadNotes() {
    final raw = _prefs.getString(_kNotes);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: {
          for (final day in (entry.value as Map<String, dynamic>).entries)
            if (readDayNotes(day.value).isNotEmpty)
              day.key: readDayNotes(day.value),
        },
    };
  }

  Future<void> saveNotes(Map<String, Map<String, List<String>>> notes) =>
      _prefs.setString(_kNotes, jsonEncode(notes));

  // -- journal --------------------------------------------------------------

  List<JournalEntry> loadJournal() {
    final raw = _prefs.getString(_kJournal);
    if (raw == null || raw.isEmpty) return [];
    return [
      for (final item in (jsonDecode(raw) as List? ?? const []))
        ?JournalEntry.fromJson(item),
    ];
  }

  Future<void> saveJournal(List<JournalEntry> entries) => _prefs.setString(
    _kJournal,
    jsonEncode([for (final e in entries) e.toJson()]),
  );

  // -- premium --------------------------------------------------------------

  PremiumStatus loadPremium() {
    final raw = _prefs.getString(_kPremium);
    if (raw == null || raw.isEmpty) return PremiumStatus.free;
    return PremiumStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>?);
  }

  Future<void> savePremium(PremiumStatus status) =>
      _prefs.setString(_kPremium, jsonEncode(status.toJson()));

  // -- profile --------------------------------------------------------------

  UserProfile? loadProfile() {
    final raw = _prefs.getString(_kProfile);
    if (raw == null || raw.isEmpty) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) =>
      _prefs.setString(_kProfile, jsonEncode(profile.toJson()));

  // -- preferences ----------------------------------------------------------

  String? loadThemeId() => _prefs.getString(_kThemeId);

  Future<void> saveThemeId(String id) => _prefs.setString(_kThemeId, id);

  /// The time of day the user has pinned, by [DayPhase.name], or null to
  /// follow the clock.
  String? loadFixedPhase() => _prefs.getString(_kFixedPhase);

  Future<void> saveFixedPhase(String? name) => name == null
      ? _prefs.remove(_kFixedPhase)
      : _prefs.setString(_kFixedPhase, name);

  /// Whether the walkthrough has been shown. Not the same as [isSeeded]:
  /// that is about data, this is about whether anybody has been introduced to
  /// the app, and clearing your data is a fair reason to be introduced again.
  bool get hasSeenTutorial => _prefs.getBool(_kTutorial) ?? false;

  Future<void> markTutorialSeen() => _prefs.setBool(_kTutorial, true);

  /// Whether the challenge's rules have been read. The path is a commitment
  /// with a real cost to breaking it, so it is worth having been agreed to
  /// once rather than discovered on the day it resets.
  bool get hasSeenChallengeRules => _prefs.getBool(_kRules) ?? false;

  Future<void> markChallengeRulesSeen() => _prefs.setBool(_kRules, true);

  /// Puts the rules back in front of somebody who cleared everything.
  Future<void> forgetChallengeRules() => _prefs.remove(_kRules);

  /// The day the 21-day challenge was begun, or null if it never was.
  ///
  /// Stored as a day rather than a flag: the count has to run from somewhere,
  /// and "how many perfect days in a row" answered over all history would put
  /// somebody on day nine of a challenge they had not joined.
  DateTime? get challengeStartedOn {
    final raw = _prefs.getString(_kChallengeStart);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setChallengeStartedOn(DateTime? day) => day == null
      ? _prefs.remove(_kChallengeStart)
      : _prefs.setString(_kChallengeStart, day.toIso8601String());

  /// The furthest stop somebody has watched themselves arrive at.
  ///
  /// Stored rather than derived, because the question is not "where are you"
  /// but "have you seen this yet", and nothing else on the device knows the
  /// answer. Zero means the challenge is not running.
  int get challengeSeenStop => _prefs.getInt(_kChallengeSeen) ?? 0;

  Future<void> setChallengeSeenStop(int stop) =>
      _prefs.setInt(_kChallengeSeen, stop);

  /// The day whose completion has already been celebrated, as a day key.
  ///
  /// On the device rather than in the screen's State: the celebration belongs
  /// to the moment a day is finished, and a field on a widget forgets that
  /// every time the app is launched — so a day finished last night got
  /// congratulated again this morning.
  String? get celebratedDay => _prefs.getString(_kCelebrated);

  /// The day the day-closed sound last played, as a day key.
  ///
  /// Separate from [celebratedDay] because that one is cleared whenever the
  /// day stops being whole, so that closing it again celebrates again. The
  /// sound is once a day, full stop: the tenth time somebody un-ticks and
  /// re-ticks a habit it should not ring a tenth time.
  String? get closeSoundDay => _prefs.getString(_kCloseSound);

  Future<void> setCloseSoundDay(String key) =>
      _prefs.setString(_kCloseSound, key);

  Future<void> setCelebratedDay(String? key) => key == null
      ? _prefs.remove(_kCelebrated)
      : _prefs.setString(_kCelebrated, key);

  /// Whether Home shows the board rather than today's list. The list is the
  /// default: it is what you need on the way past, where the board is
  /// something you go and look at.
  bool get homeShowsBoard => _prefs.getBool(_kBoard) ?? false;

  Future<void> setHomeShowsBoard(bool on) => _prefs.setBool(_kBoard, on);

  bool get isSeeded => _prefs.getBool(_kSeeded) ?? false;

  Future<void> markSeeded() => _prefs.setBool(_kSeeded, true);

  // -- notifications --------------------------------------------------------

  NotificationPrefs loadNotificationPrefs() {
    final raw = _prefs.getString(_kNotifyPrefs);
    if (raw == null || raw.isEmpty) return const NotificationPrefs();
    return NotificationPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveNotificationPrefs(NotificationPrefs prefs) =>
      _prefs.setString(_kNotifyPrefs, jsonEncode(prefs.toJson()));

  /// Whether the 21-day path plays its music. On until turned off.
  bool get challengeMusicOn => _prefs.getBool(_kChallengeMusic) ?? true;

  Future<void> setChallengeMusicOn(bool on) =>
      _prefs.setBool(_kChallengeMusic, on);

  /// Every key the app has ever written, gone: what a new install finds.
  ///
  /// Not [clear], which names the keys it removes and so misses any added
  /// since — the challenge, the day-closed sound, the celebrated day.
  Future<void> wipe() => _prefs.clear();

  /// Wipes everything — used by the future "reset my data" action.
  Future<void> clear() async {
    for (final key in [
      _kHabits,
      _kLogs,
      _kNotes,
      _kProfile,
      _kThemeId,
      _kSeeded,
      _kNotifyPrefs,
      _kFixedPhase,
      _kTutorial,
      _kRules,
      _kBoard,
    ]) {
      await _prefs.remove(key);
    }
  }
}
