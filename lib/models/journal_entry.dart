import 'package:flutter/foundation.dart';

import 'habit_log.dart';

/// One journal entry: a mood, a few feelings, and the words, if any.
///
/// Words are optional on purpose. A tap on a face is an entry — the blank page
/// is the reason most people stop journaling, and a day with a mood and no
/// sentence is still a day on the record, and still counts in the insights.
@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.day,
    required this.createdAt,
    required this.updatedAt,
    required this.template,
    this.mood,
    this.feelings = const [],
    this.answers = const {},
  });

  final String id;

  /// The day it is about — not always the day it was written.
  final DateTime day;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Which set of prompts it was written against: `evening`, `morning`,
  /// `gratitude`, `free` or `checkin`.
  final String template;

  /// 1 (rough) to 5 (great), or null when none was chosen.
  final int? mood;

  /// Feeling keys, from `JournalContent.feelings`.
  final List<String> feelings;

  /// What was written, by prompt key.
  final Map<String, String> answers;

  /// Everything written, in prompt order, with the empty ones left out.
  List<String> get lines => [
    for (final text in answers.values)
      if (text.trim().isNotEmpty) text.trim(),
  ];

  bool get hasWords => lines.isNotEmpty;

  JournalEntry copyWith({
    DateTime? day,
    DateTime? updatedAt,
    String? template,
    int? mood,
    bool clearMood = false,
    List<String>? feelings,
    Map<String, String>? answers,
  }) => JournalEntry(
    id: id,
    day: day ?? this.day,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    template: template ?? this.template,
    mood: clearMood ? null : (mood ?? this.mood),
    feelings: feelings ?? this.feelings,
    answers: answers ?? this.answers,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': dayKey(day),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'template': template,
    if (mood != null) 'mood': mood,
    if (feelings.isNotEmpty) 'feelings': feelings,
    if (answers.isNotEmpty) 'answers': answers,
  };

  static JournalEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final day = DateTime.tryParse(raw['day'] as String? ?? '');
    final id = raw['id'] as String?;
    if (day == null || id == null) return null;
    final created = DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? day;
    return JournalEntry(
      id: id,
      day: DateTime(day.year, day.month, day.day),
      createdAt: created,
      updatedAt:
          DateTime.tryParse(raw['updatedAt'] as String? ?? '') ?? created,
      template: raw['template'] as String? ?? 'free',
      mood: (raw['mood'] as num?)?.toInt().clamp(1, 5),
      feelings: [
        for (final f in (raw['feelings'] as List? ?? const []))
          if (f is String) f,
      ],
      answers: {
        for (final e in ((raw['answers'] as Map?) ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
    );
  }
}
