/// The four views on the Progress tab.
enum ProgressRange {
  week('This Week'),
  month('This Month'),
  year('This Year'),
  allTime('All Time');

  const ProgressRange(this.label);

  /// Text on the range selector chip.
  final String label;
}
