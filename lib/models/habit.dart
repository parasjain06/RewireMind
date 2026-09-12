import 'package:flutter/foundation.dart';

import 'habit_log.dart';

/// What kind of change the habit represents.
///
/// A good day for a [build] habit means doing the thing; for a [quit] habit it
/// means *not* doing it. They are tracked identically underneath — one daily
/// tick — but read very differently, so the UI phrases them apart.
enum HabitKind { build, quit }

/// A habit the user is tracking.
///
/// [iconKey] is looked up in two places, so a habit's look is fully
/// theme-driven: `AppIcons.forKey` (glyph) and `colors.accentFor` (colours).
@immutable
class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.target,
    required this.unit,
    required this.createdAt,
    this.kind = HabitKind.build,
    this.activeWeekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.archivedAt,
    this.sortOrder = 0,
    this.colorValue,
  }) : startDay = dateOnly(createdAt),
       endDay = archivedAt == null ? null : dateOnly(archivedAt);

  final String id;
  final String name;

  /// Key into the icon catalogue and the theme's accent map
  /// (water, book, exercise, meditate, sleep, ...).
  final String iconKey;

  /// How much counts as done for one day (2 for "Drink 2L water").
  final double target;

  /// Unit shown beside progress ("L", "min", "pages", "time").
  final String unit;

  final HabitKind kind;

  /// Weekdays this habit is scheduled on, 1 = Monday … 7 = Sunday.
  final Set<int> activeWeekdays;

  final DateTime createdAt;

  /// The day tracking stopped, or null while it is ongoing.
  ///
  /// Discontinuing sets this rather than deleting, so the habit's past stays
  /// in the record and historical statistics do not change retroactively.
  final DateTime? archivedAt;

  final int sortOrder;

  /// The habit's own colour, as an ARGB value, or null to take the one the
  /// theme gives its icon.
  ///
  /// Null rather than a default so the two systems do not fight: every icon
  /// already has an accent, and a habit that has never been given a colour
  /// should follow the theme rather than freeze whatever the accent happened
  /// to be on the day it was created.
  final int? colorValue;

  bool get isArchived => archivedAt != null;

  /// A single daily tick rather than a measured amount.
  bool get isBinary => target == 1;

  /// How much one press of + adds — a glass, five minutes, a page.
  ///
  /// The same number everywhere it is offered: the stepper on the habit's own
  /// page and the button on its reminder. Small whole targets go up one at a
  /// time, because that is what a glass of water is; larger ones move in a
  /// round fraction, so eight taps never stand between somebody and a logged
  /// day.
  double get step {
    if (isBinary) return target;
    if (target <= 12 && target == target.roundToDouble()) return 1;
    final rough = target / 5;
    for (final nice in const <double>[
      0.5,
      1,
      2,
      5,
      10,
      15,
      20,
      25,
      30,
      50,
      100,
    ]) {
      if (rough <= nice) return nice;
    }
    return (target / 4).roundToDouble();
  }

  /// "1 glass", "5 min", "2" — one step, said out loud.
  ///
  /// Units are stored as they read on a whole day — glasses, pages, min — so
  /// one of them has to lose its plural, or a button offers "+1 glasses".
  String get stepLabel {
    final amount = _trim(step);
    if (unit.isEmpty) return amount;
    var word = unit;
    if (step == 1) {
      if (word.endsWith('sses')) {
        word = word.substring(0, word.length - 2);
      } else if (word.length > 2 && word.endsWith('s')) {
        word = word.substring(0, word.length - 1);
      }
    }
    return '$amount $word';
  }

  /// Lifetime bounds, precomputed — these are read once per habit per day
  /// across the whole history, so they must not allocate.
  final DateTime startDay;
  final DateTime? endDay;

  /// Whether [day] falls on one of this habit's weekdays.
  bool isScheduledOn(DateTime day) => activeWeekdays.contains(day.weekday);

  /// Whether [day] falls inside the habit's life: on or after the day it
  /// started, and on or before the day it stopped. Says nothing about the
  /// weekday — a Sunday for a weekday-only habit is inside its life and off
  /// its schedule, and the two are drawn differently.
  bool isWithinLifetime(DateTime day) {
    if (day.isBefore(startDay)) return false;
    final end = endDay;
    return end == null || !day.isAfter(end);
  }

  /// Whether the habit was being tracked on [day] — on-schedule and inside its
  /// lifetime. This is what every statistic counts against.
  ///
  /// [day] must already be midnight-normalised; use [isActiveOn] otherwise.
  bool isActiveOnDay(DateTime day) =>
      activeWeekdays.contains(day.weekday) && isWithinLifetime(day);

  /// Normalising wrapper around [isActiveOnDay].
  bool isActiveOn(DateTime day) => isActiveOnDay(dateOnly(day));

  /// "0 / 2 L" style progress label.
  String progressLabel(double value) {
    final v = _trim(value);
    final t = _trim(target);
    return unit.isEmpty ? '$v / $t' : '$v / $t $unit';
  }

  static String _trim(double n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();

  Habit copyWith({
    DateTime? createdAt,
    String? name,
    String? iconKey,
    double? target,
    String? unit,
    HabitKind? kind,
    Set<int>? activeWeekdays,
    int? sortOrder,
    DateTime? archivedAt,
    bool clearArchived = false,
    int? colorValue,
    bool clearColor = false,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      target: target ?? this.target,
      unit: unit ?? this.unit,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      activeWeekdays: activeWeekdays ?? this.activeWeekdays,
      archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
      sortOrder: sortOrder ?? this.sortOrder,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconKey': iconKey,
    'target': target,
    'unit': unit,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'activeWeekdays': activeWeekdays.toList()..sort(),
    'archivedAt': archivedAt?.toIso8601String(),
    'sortOrder': sortOrder,
    'colorValue': colorValue,
  };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final archivedRaw = json['archivedAt'] as String?;
    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      iconKey: json['iconKey'] as String? ?? 'book',
      target: (json['target'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? '',
      kind: HabitKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => HabitKind.build,
      ),
      createdAt: created,
      activeWeekdays:
          (json['activeWeekdays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          const {1, 2, 3, 4, 5, 6, 7},
      // Older records stored a plain `archived` flag with no date.
      archivedAt: archivedRaw != null
          ? DateTime.tryParse(archivedRaw)
          : (json['archived'] == true ? created : null),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      colorValue: (json['colorValue'] as num?)?.toInt(),
    );
  }
}
