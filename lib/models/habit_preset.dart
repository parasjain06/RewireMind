import 'package:flutter/foundation.dart';

import 'habit.dart';

/// Sections of the habit library.
enum HabitCategory { popular, health, sports, mindful, lifestyle, quit }

/// A ready-made habit the user can add in one tap.
///
/// Presets carry sensible defaults; the editor opens prefilled from one when
/// the user wants to change the goal before adding.
@immutable
class HabitPreset {
  const HabitPreset({
    required this.name,
    required this.iconKey,
    required this.target,
    required this.unit,
    this.kind = HabitKind.build,
  });

  final String name;
  final String iconKey;
  final double target;
  final String unit;
  final HabitKind kind;

  /// "30 min", "8 glasses" — the goal shown under the preset's name.
  String get goalLabel {
    if (kind == HabitKind.quit) return 'One tick a day';
    final t = target == target.roundToDouble()
        ? target.round().toString()
        : target.toString();
    return unit.isEmpty ? t : '$t $unit';
  }
}
