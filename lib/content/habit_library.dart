import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_preset.dart';

/// ============================================================================
/// HABIT LIBRARY
/// ============================================================================
/// The ready-made habits offered when adding a new one, grouped into
/// categories. Edit this file to change what the library offers — no screen
/// code needs to know.
///
/// Every `iconKey` must exist in both `AppIcons` (glyph) and the theme's
/// `colors.accents` map (colours).
/// ============================================================================

class HabitLibrary {
  const HabitLibrary._();

  /// The order the chips are shown in, which is not the order the enum is
  /// declared in.
  ///
  /// "Cut back" used to sit at the end, which on a phone meant scrolling the
  /// strip to its far edge to find the only chip that offers a different *kind*
  /// of habit rather than a different topic. Second, beside Popular, it is
  /// visible the moment the screen opens — which is the whole point of it
  /// being there.
  static const List<HabitCategory> order = [
    HabitCategory.popular,
    HabitCategory.quit,
    HabitCategory.health,
    HabitCategory.sports,
    HabitCategory.mindful,
    HabitCategory.lifestyle,
  ];

  static const Map<HabitCategory, String> labels = {
    HabitCategory.popular: 'Popular',
    HabitCategory.health: 'Health',
    HabitCategory.sports: 'Sports',
    HabitCategory.mindful: 'Mindful',
    HabitCategory.lifestyle: 'Lifestyle',
    HabitCategory.quit: 'Cut back',
  };

  static const Map<HabitCategory, IconData> icons = {
    HabitCategory.popular: Icons.local_fire_department,
    HabitCategory.health: Icons.favorite,
    HabitCategory.sports: Icons.directions_run,
    HabitCategory.mindful: Icons.spa,
    HabitCategory.lifestyle: Icons.home_outlined,
    HabitCategory.quit: Icons.block,
  };

  /// A short line under the category chips explaining the section.
  static const Map<HabitCategory, String> blurbs = {
    HabitCategory.popular: 'The habits most people start with',
    HabitCategory.health: 'Look after the basics',
    HabitCategory.sports: 'Get your body moving',
    HabitCategory.mindful: 'Time for your head, not your to-do list',
    HabitCategory.lifestyle: 'Small things that make days run better',
    HabitCategory.quit: 'Habits where less is the win',
  };

  static const Map<HabitCategory, List<HabitPreset>> presets = {
    HabitCategory.popular: [
      HabitPreset(
        name: 'Drink water',
        iconKey: 'water',
        target: 8,
        unit: 'glasses',
      ),
      HabitPreset(name: 'Sleep', iconKey: 'sleep', target: 8, unit: 'hours'),
      HabitPreset(name: 'Walk', iconKey: 'walk', target: 30, unit: 'min'),
      HabitPreset(
        name: 'Meditate',
        iconKey: 'meditate',
        target: 10,
        unit: 'min',
      ),
      HabitPreset(name: 'Read', iconKey: 'book', target: 10, unit: 'pages'),
      HabitPreset(
        name: 'Exercise',
        iconKey: 'exercise',
        target: 30,
        unit: 'min',
      ),
      HabitPreset(name: 'Stretch', iconKey: 'stretch', target: 10, unit: 'min'),
      HabitPreset(name: 'Journal', iconKey: 'journal', target: 1, unit: 'time'),
      HabitPreset(
        name: 'Eat fruit',
        iconKey: 'fruit',
        target: 2,
        unit: 'times',
      ),
      HabitPreset(
        name: 'Less sugar',
        iconKey: 'sugar',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
    ],
    HabitCategory.health: [
      HabitPreset(
        name: 'Drink water',
        iconKey: 'water',
        target: 8,
        unit: 'glasses',
      ),
      HabitPreset(name: 'Sleep', iconKey: 'sleep', target: 8, unit: 'hours'),
      HabitPreset(
        name: 'Early night',
        iconKey: 'sleep',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(
        name: 'Take vitamins',
        iconKey: 'vitamins',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(
        name: 'Eat vegetables',
        iconKey: 'vegetables',
        target: 3,
        unit: 'times',
      ),
      HabitPreset(
        name: 'Eat fruit',
        iconKey: 'fruit',
        target: 2,
        unit: 'times',
      ),
      HabitPreset(
        name: 'Eat breakfast',
        iconKey: 'breakfast',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(name: 'Cook', iconKey: 'meal', target: 1, unit: 'time'),
      HabitPreset(name: 'Stand up', iconKey: 'stand', target: 8, unit: 'times'),
      HabitPreset(name: 'Herbal tea', iconKey: 'tea', target: 1, unit: 'time'),
    ],
    HabitCategory.sports: [
      HabitPreset(name: 'Walk', iconKey: 'walk', target: 30, unit: 'min'),
      HabitPreset(
        name: 'Steps',
        iconKey: 'steps',
        target: 10000,
        unit: 'steps',
      ),
      HabitPreset(name: 'Run', iconKey: 'run', target: 5, unit: 'km'),
      HabitPreset(name: 'Cycling', iconKey: 'cycle', target: 20, unit: 'min'),
      HabitPreset(name: 'Swim', iconKey: 'swim', target: 30, unit: 'min'),
      HabitPreset(name: 'Yoga', iconKey: 'yoga', target: 20, unit: 'min'),
      HabitPreset(name: 'Stretch', iconKey: 'stretch', target: 10, unit: 'min'),
      HabitPreset(
        name: 'Workout',
        iconKey: 'exercise',
        target: 45,
        unit: 'min',
      ),
      HabitPreset(
        name: 'Push-ups',
        iconKey: 'exercise',
        target: 30,
        unit: 'reps',
      ),
      HabitPreset(
        name: 'Calories',
        iconKey: 'calories',
        target: 500,
        unit: 'cal',
      ),
      HabitPreset(name: 'Sport', iconKey: 'sports', target: 60, unit: 'min'),
    ],
    HabitCategory.mindful: [
      HabitPreset(
        name: 'Meditate',
        iconKey: 'meditate',
        target: 10,
        unit: 'min',
      ),
      HabitPreset(name: 'Breathe', iconKey: 'breathe', target: 5, unit: 'min'),
      HabitPreset(name: 'Journal', iconKey: 'journal', target: 1, unit: 'time'),
      HabitPreset(
        name: 'Gratitude',
        iconKey: 'gratitude',
        target: 3,
        unit: 'times',
      ),
      HabitPreset(name: 'Read', iconKey: 'book', target: 10, unit: 'pages'),
      HabitPreset(name: 'Learn', iconKey: 'study', target: 30, unit: 'min'),
      HabitPreset(name: 'Reflect', iconKey: 'review', target: 1, unit: 'time'),
      HabitPreset(name: 'Music', iconKey: 'music', target: 20, unit: 'min'),
      HabitPreset(
        name: 'Outdoors',
        iconKey: 'outdoors',
        target: 30,
        unit: 'min',
      ),
    ],
    HabitCategory.lifestyle: [
      HabitPreset(
        name: 'Expenses',
        iconKey: 'expenses',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(
        name: 'Save money',
        iconKey: 'money',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(name: 'Tidy up', iconKey: 'tidy', target: 15, unit: 'min'),
      HabitPreset(
        name: 'Plan tomorrow',
        iconKey: 'plan',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(
        name: 'Call family',
        iconKey: 'family',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(
        name: 'Skincare',
        iconKey: 'selfcare',
        target: 1,
        unit: 'time',
      ),
      HabitPreset(name: 'Language', iconKey: 'study', target: 15, unit: 'min'),
      HabitPreset(name: 'Weigh in', iconKey: 'weight', target: 1, unit: 'time'),
    ],
    HabitCategory.quit: [
      HabitPreset(
        name: 'Less sugar',
        iconKey: 'sugar',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less caffeine',
        iconKey: 'caffeine',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less alcohol',
        iconKey: 'alcohol',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less smoking',
        iconKey: 'smoking',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less social media',
        iconKey: 'social',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less TV',
        iconKey: 'tv',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less gaming',
        iconKey: 'game',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less sitting',
        iconKey: 'sitting',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less spending',
        iconKey: 'spending',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
      HabitPreset(
        name: 'Less junk food',
        iconKey: 'junk',
        target: 1,
        unit: '',
        kind: HabitKind.quit,
      ),
    ],
  };

  static List<HabitPreset> forCategory(HabitCategory category) =>
      presets[category] ?? const [];

  // -- screen copy ----------------------------------------------------------

  /// Names both halves of what this screen does. "Add a habit" read as
  /// though cutting something back were a different feature living somewhere
  /// else, when it is the same list with one chip in it.
  static const String screenTitle = 'Build or cut back';
  static const String customButton = 'Custom habit';
  static const String added = 'Added';

  static const String remove = 'Remove';

  /// "Drink water removed" — said after the fact, because the row itself has
  /// already changed back and a confirmation would be two taps for something
  /// one tap can undo.
  static String removed(String name) => '$name removed';
  static const String addedToast = 'added to your habits';
  static const String tapToAdjust = 'Tap a habit to adjust its goal first';
}
