/// Where the sun is, which drives both the header artwork and the palette of
/// the entire page.
///
/// Lives in models rather than beside the illustration because the theme reads
/// it too — the whole app retints with the time of day, not just the header.
enum DayPhase {
  earlyMorning,
  day,
  night;

  /// The phase for a given clock time.
  ///
  ///   05:00 – 09:59  early morning
  ///   10:00 – 18:59  day
  ///   19:00 – 04:59  night
  static DayPhase of(DateTime now) {
    final h = now.hour;
    if (h < 5) return DayPhase.night;
    if (h < 10) return DayPhase.earlyMorning;
    if (h < 19) return DayPhase.day;
    return DayPhase.night;
  }

  /// True when the page is painted dark and text has to invert.
  bool get isDark => this == DayPhase.night;

  String get label => switch (this) {
    DayPhase.earlyMorning => 'Early morning',
    DayPhase.day => 'Day',
    DayPhase.night => 'Night',
  };
}
