import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/journal_content.dart';
import '../models/journal_entry.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'completion_effects.dart';
import 'k_card.dart';

/// The five faces, one of them chosen.
///
/// Big enough to hit without looking, each in its own colour, and the chosen
/// one lifts and says its name — the whole of a check-in, in one row. Without
/// [labels] it shrinks to just the faces, for the strip on Home.
class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.selected,
    required this.onPick,
    this.size = 46,
    this.labels = true,
  });

  final int? selected;
  final ValueChanged<int> onPick;
  final double size;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final calm = reduceMotion(context);
    return Row(
      mainAxisSize: labels ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final mood in JournalContent.moods)
          _flex(
            labels,
            Semantics(
              button: true,
              selected: selected == mood.value,
              label: mood.label,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(mood.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      duration: Duration(milliseconds: calm ? 0 : 220),
                      curve: Curves.easeOutBack,
                      scale: selected == mood.value ? 1.12 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(mood.colour).withValues(
                            alpha: selected == mood.value ? 0.22 : 0.10,
                          ),
                          border: Border.all(
                            color: Color(mood.colour).withValues(
                              alpha: selected == mood.value ? 0.9 : 0.0,
                            ),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          mood.icon,
                          size: size * 0.62,
                          color: Color(mood.colour).withValues(
                            alpha: selected == null || selected == mood.value
                                ? 1
                                : 0.55,
                          ),
                        ),
                      ),
                    ),
                    if (labels) ...[
                      const SizedBox(height: 5),
                      Text(
                        mood.label,
                        style: k.text.caption.copyWith(
                          fontSize: 11,
                          fontWeight: selected == mood.value
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected == mood.value
                              ? Color(mood.colour)
                              : k.colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Sharing the row out between the five faces, or letting them take only
  /// the width they need — a row of its own, or a row inside another.
  Widget _flex(bool spread, Widget child) => spread
      ? Expanded(child: child)
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: child,
        );
}

/// A small face for a mood, for lists and the calendar.
class MoodFace extends StatelessWidget {
  const MoodFace({super.key, required this.mood, this.size = 28});

  final int? mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final m = mood == null ? null : JournalContent.mood(mood!);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: m == null
            ? k.colors.surfaceSoft
            : Color(m.colour).withValues(alpha: 0.16),
      ),
      child: Icon(
        m?.icon ?? Icons.edit_note_rounded,
        size: size * 0.66,
        color: m == null ? k.colors.textMuted : Color(m.colour),
      ),
    );
  }
}

/// On Home, on its own line under the list: how the day is going, in one tap.
///
/// A strip rather than a card, and pinned rather than the last thing in the
/// list — at the end of a scroll it read as a stray habit, and it turned up
/// again at the bottom of both Build and Cut back. Here it keeps one place,
/// whichever list is on screen and however far it is scrolled.
///
/// One line throughout: the five faces until one is picked, then the words
/// that go with it — the shortest entry there is, with the journal itself one
/// tap further on.
class JournalCheckInBar extends StatefulWidget {
  const JournalCheckInBar({
    super.key,
    required this.day,
    required this.onOpenJournal,
    required this.onWrite,
  });

  final DateTime day;
  final VoidCallback onOpenJournal;

  /// Opens the editor on the day's entry, or a new one.
  final ValueChanged<JournalEntry?> onWrite;

  @override
  State<JournalCheckInBar> createState() => _JournalCheckInBarState();
}

class _JournalCheckInBarState extends State<JournalCheckInBar> {
  /// Showing the faces rather than what was picked. Set by tapping the face,
  /// to change an answer; cleared by picking one.
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final entries = state.journalOn(widget.day);
    final latest = entries.isEmpty ? null : entries.first;
    final mood = state.moodOn(widget.day);
    final calm = reduceMotion(context);
    final faces = mood == null || _picking;

    return KCard(
      soft: true,
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: calm ? 0 : 200),
                child: faces
                    ? _Ask(
                        key: const ValueKey('ask'),
                        day: widget.day,
                        today: state.today,
                        selected: mood,
                        onPick: (value) async {
                          await state.checkIn(value, day: widget.day);
                          if (mounted) setState(() => _picking = false);
                        },
                      )
                    : _Picked(
                        key: const ValueKey('picked'),
                        mood: mood,
                        entry: latest,
                        onChange: () => setState(() => _picking = true),
                        onWrite: () => widget.onWrite(latest),
                      ),
              ),
            ),
            // The way through to the journal itself, in the same place in
            // both states.
            Semantics(
              button: true,
              label: JournalContent.homeOpen,
              child: IconButton(
                onPressed: widget.onOpenJournal,
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                color: k.colors.accent,
                icon: const Icon(Icons.auto_stories_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The question, and the five faces to answer it with.
class _Ask extends StatelessWidget {
  const _Ask({
    super.key,
    required this.day,
    required this.today,
    required this.selected,
    required this.onPick,
  });

  final DateTime day;
  final DateTime today;
  final int? selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ask = day != today
        ? JournalContent.homeAskPast
        : (DateTime.now().hour >= 17
              ? JournalContent.homeAskEvening
              : JournalContent.homeAsk);
    return Row(
      children: [
        // Shrinks rather than truncates: the five faces beside it are a fixed
        // width, and "How was today?" arrived on a narrow phone as
        // "How was to…", which reads as a bug rather than a question.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              ask,
              maxLines: 1,
              style: k.text.cardTitle.copyWith(fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(width: 6),
        MoodPicker(selected: selected, size: 30, labels: false, onPick: onPick),
      ],
    );
  }
}

/// What was picked, and the words that go with it.
class _Picked extends StatelessWidget {
  const _Picked({
    super.key,
    required this.mood,
    required this.entry,
    required this.onChange,
    required this.onWrite,
  });

  final int? mood;
  final JournalEntry? entry;
  final VoidCallback onChange;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final words = entry?.hasWords == true ? entry!.lines.first : null;
    return Row(
      children: [
        Semantics(
          button: true,
          label: JournalContent.homeChange,
          child: InkResponse(
            onTap: onChange,
            radius: 26,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: MoodFace(mood: mood, size: 30),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(k.geometry.innerRadius),
            onTap: onWrite,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  if (words == null) ...[
                    Icon(Icons.add, size: 16, color: k.colors.primary),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      words ?? JournalContent.homeAddWords,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: words != null
                          ? k.text.body.copyWith(fontSize: 13.5)
                          : k.text.captionStrong.copyWith(
                              color: k.colors.primary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
