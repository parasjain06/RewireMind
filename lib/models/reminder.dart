import 'package:flutter/foundation.dart';

/// A wall-clock time of day. Deliberately not [DateTime]: these are times that
/// recur, not moments that happened.
@immutable
class TimeOfDayValue implements Comparable<TimeOfDayValue> {
  const TimeOfDayValue(this.hour, this.minute);

  /// 24-hour clock internally; every display goes through [format].
  final int hour;
  final int minute;

  int get minutesFromMidnight => hour * 60 + minute;

  /// This time of day, on [day].
  DateTime onDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// "8:30 AM" — always twelve-hour with a meridiem, whatever the device
  /// locale does, because a reminder list full of 20:30 reads like a train
  /// timetable.
  String format() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} $meridiem';
  }

  String get meridiem => hour < 12 ? 'AM' : 'PM';

  @override
  int compareTo(TimeOfDayValue other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayValue && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  Map<String, dynamic> toJson() => {'h': hour, 'm': minute};

  static TimeOfDayValue fromJson(Map<String, dynamic> json) =>
      TimeOfDayValue(json['h'] as int, json['m'] as int);
}

/// One reminder, exactly as the user set it up.
///
/// The app does not decide what to say or when — this is the whole
/// specification, and the scheduler simply carries it out. Anything clever
/// (skipping a finished day, filling in a quote) is opt-in and visible.
@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.text,
    required this.time,
    this.habitId,
    this.weekdays = everyDay,
    this.enabled = true,
    this.skipWhenDone = true,
    this.withQuote = false,
    this.sortOrder = 0,
  });

  static const Set<int> everyDay = {1, 2, 3, 4, 5, 6, 7};
  static const Set<int> weekdaysOnly = {1, 2, 3, 4, 5};
  static const Set<int> weekendsOnly = {6, 7};

  final String id;

  /// The habit this reminder belongs to, or null for a general one.
  ///
  /// A habit-scoped reminder resolves `{habit}` to its own habit rather than
  /// whatever happens to be outstanding first, and "skip if done" means that
  /// habit specifically.
  final String? habitId;

  bool get isForHabit => habitId != null;

  /// The whole message. One field rather than a title and a body: a
  /// reminder is a single sentence, and splitting it in two made the
  /// editor feel like filling in a form.
  final String text;

  final TimeOfDayValue time;

  /// Days this reminder fires on, 1 = Monday … 7 = Sunday.
  final Set<int> weekdays;

  final bool enabled;

  /// Suppresses the reminder on days where every scheduled habit is already
  /// logged. Chasing someone for something they finished at six is the fastest
  /// way to get notifications switched off altogether — but it is a choice,
  /// not a rule, so it sits on the reminder rather than in the scheduler.
  final bool skipWhenDone;

  /// Appends the day's motivational line underneath [text].
  final bool withQuote;

  final int sortOrder;

  bool firesOn(DateTime day) => enabled && weekdays.contains(day.weekday);

  /// "Every day" / "Weekdays" / "Weekends" / "Mon, Wed, Fri"
  String get scheduleLabel {
    if (weekdays.length == 7) return 'Every day';
    if (setEquals(weekdays, weekdaysOnly)) return 'Weekdays';
    if (setEquals(weekdays, weekendsOnly)) return 'Weekends';
    if (weekdays.isEmpty) return 'Never';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = weekdays.toList()..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  Reminder copyWith({
    String? text,
    TimeOfDayValue? time,
    Set<int>? weekdays,
    bool? enabled,
    bool? skipWhenDone,
    bool? withQuote,
    int? sortOrder,
  }) {
    return Reminder(
      id: id,
      habitId: habitId,
      text: text ?? this.text,
      time: time ?? this.time,
      weekdays: weekdays ?? this.weekdays,
      enabled: enabled ?? this.enabled,
      skipWhenDone: skipWhenDone ?? this.skipWhenDone,
      withQuote: withQuote ?? this.withQuote,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (habitId != null) 'habitId': habitId,
    'text': text,
    'time': time.toJson(),
    'weekdays': weekdays.toList()..sort(),
    'enabled': enabled,
    'skipWhenDone': skipWhenDone,
    'withQuote': withQuote,
    'sortOrder': sortOrder,
  };

  static Reminder fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as String,
    habitId: json['habitId'] as String?,
    text: json['text'] as String? ?? json['title'] as String? ?? '',
    time: TimeOfDayValue.fromJson(json['time'] as Map<String, dynamic>),
    weekdays: {
      for (final d in (json['weekdays'] as List? ?? const []))
        (d as num).toInt(),
    },
    enabled: json['enabled'] as bool? ?? true,
    skipWhenDone: json['skipWhenDone'] as bool? ?? true,
    withQuote: json['withQuote'] as bool? ?? false,
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  );
}
