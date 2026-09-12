/// One note, on one habit, on one day.
///
/// A day can hold several — "skipped the morning run" and later "did it in the
/// evening after all" are two notes, and making the second overwrite the first
/// threw away exactly the part of the story that changed. [index] is its place
/// among that day's notes, oldest first, which is how it is edited or deleted.
class HabitNote {
  const HabitNote({required this.day, required this.index, required this.text});

  final DateTime day;
  final int index;
  final String text;
}

/// Reads one day's notes from storage or a backup, in either shape.
///
/// Notes used to be a single string per day. Anything saved or exported
/// before a day could hold more than one still arrives that way, so a string
/// is read as a list of one rather than refused.
List<String> readDayNotes(Object? raw) {
  if (raw is String) return raw.trim().isEmpty ? <String>[] : <String>[raw];
  if (raw is List) {
    return [
      for (final note in raw)
        if (note is String && note.trim().isNotEmpty) note,
    ];
  }
  return <String>[];
}
