import 'package:flutter/foundation.dart';

/// Strips the time component so a day can be used as a map key.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Canonical `yyyy-MM-dd` key for a day.
String dayKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime dayFromKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// How much of a habit was done on one day.
///
/// Only days with progress are stored; a missing entry means zero.
@immutable
class HabitLog {
  const HabitLog({
    required this.habitId,
    required this.day,
    required this.value,
  });

  final String habitId;

  /// Midnight-normalised day this progress belongs to.
  final DateTime day;

  /// Progress recorded, in the habit's own unit.
  final double value;

  HabitLog copyWith({double? value}) =>
      HabitLog(habitId: habitId, day: day, value: value ?? this.value);

  Map<String, dynamic> toJson() => {
    'habitId': habitId,
    'day': dayKey(day),
    'value': value,
  };

  factory HabitLog.fromJson(Map<String, dynamic> json) => HabitLog(
    habitId: json['habitId'] as String,
    day: dayFromKey(json['day'] as String),
    value: (json['value'] as num).toDouble(),
  );
}
