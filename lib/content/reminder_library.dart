import 'package:flutter/foundation.dart';

/// ============================================================================
/// REMINDER PRESETS
/// ============================================================================
/// Ready-made wording, so setting up a reminder never starts at a blank field.
/// Every one of these is editable after it is picked — a starting point, not a
/// menu.
///
/// Habit presets contain `{habit}`, but nobody ever sees it: the picker swaps
/// in the real habit name before the wording reaches the editor.
///
/// To change the app's voice, edit this file and nothing else.
/// ============================================================================

@immutable
class ReminderPreset {
  const ReminderPreset(this.text);

  /// The whole message. One line — a reminder is read at a glance.
  final String text;
}

@immutable
class ReminderCategory {
  const ReminderCategory({
    required this.id,
    required this.name,
    required this.blurb,
    required this.emoji,
    required this.presets,
  });

  final String id;
  final String name;
  final String blurb;
  final String emoji;
  final List<ReminderPreset> presets;
}

class ReminderLibrary {
  const ReminderLibrary._();

  static const List<ReminderCategory> categories = [
    ReminderCategory(
      id: 'gentle',
      name: 'Gentle',
      blurb: 'Warm and unhurried.',
      emoji: '🌱',
      presets: [
        ReminderPreset('Fresh page 🌅'),
        ReminderPreset('Morning. No rush. 🌿'),
        ReminderPreset('A good moment to start 🤍'),
        ReminderPreset('Small steps 🌱'),
        ReminderPreset('Whenever you are ready'),
        ReminderPreset('Evening check 🌙'),
      ],
    ),
    ReminderCategory(
      id: 'funny',
      name: 'Funny',
      blurb: 'The ones that get a smile.',
      emoji: '😄',
      presets: [
        ReminderPreset('Scoreboard: nil ☀️'),
        ReminderPreset('Your habits called ☎️'),
        ReminderPreset('Awkward 😬'),
        ReminderPreset('Plot twist: you could just do it 🍿'),
        ReminderPreset('Beep boop. Reminding you. 🤖'),
        ReminderPreset('We both know 🕵️'),
        ReminderPreset('Day almost over 🌙'),
        ReminderPreset('Still nothing? Bold. 😏'),
      ],
    ),
    ReminderCategory(
      id: 'tough',
      name: 'Tough love',
      blurb: 'For when nice is not working.',
      emoji: '🔥',
      presets: [
        ReminderPreset('No excuses ⚡'),
        ReminderPreset('Future you is watching 👀'),
        ReminderPreset('Zero so far. That is a choice.'),
        ReminderPreset('Do it badly. Just do it. 🔥'),
        ReminderPreset('Last call 🔥'),
        ReminderPreset('Earn tomorrow'),
      ],
    ),
    ReminderCategory(
      id: 'elegant',
      name: 'Elegant',
      blurb: 'Quiet and understated.',
      emoji: '🤍',
      presets: [
        ReminderPreset('Today'),
        ReminderPreset('A moment'),
        ReminderPreset('Evening'),
        ReminderPreset('Consistency'),
        ReminderPreset('Close the day'),
        ReminderPreset('Begin'),
      ],
    ),
  ];

  /// Wording for a reminder attached to one habit. `{habit}` is replaced with
  /// the habit's real name before it is shown or saved.
  static const List<ReminderPreset> habitPresets = [
    ReminderPreset('Time for {habit} ⏰'),
    ReminderPreset('{habit} 🌱'),
    ReminderPreset('{habit} is waiting 👀'),
    ReminderPreset('Quick one: {habit}'),
    ReminderPreset('{habit}? No pressure.'),
    ReminderPreset('Do not think. {habit} 🔥'),
    ReminderPreset("{habit} o'clock 🕐"),
    ReminderPreset('One rep: {habit}'),
  ];

  /// Starting reminders for someone who has just switched notifications on.
  /// Two, not four — the list is meant to be added to.
  static const List<ReminderPreset> starters = [
    ReminderPreset('Fresh page 🌅'),
    ReminderPreset('Day almost over 🌙'),
  ];

  static ReminderCategory byId(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
}
