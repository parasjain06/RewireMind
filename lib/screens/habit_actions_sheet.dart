import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/k_card.dart';
import 'home_screen.dart';
import 'home_shell.dart';

/// Long-press menu for a habit row.
///
/// Everything here is reachable elsewhere too — the detail screen has the same
/// lifecycle actions — but a long press is the fastest route when the list is
/// what you are looking at.
class HabitActionsSheet extends StatelessWidget {
  const HabitActionsSheet({super.key, required this.habit, required this.day});

  final Habit habit;
  final DateTime day;

  static Future<void> show(
    BuildContext context, {
    required Habit habit,
    required DateTime day,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitActionsSheet(habit: habit, day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final notes = state.notesOn(habit.id, day);

    return Container(
      decoration: BoxDecoration(
        color: k.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: k.colors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  IconChip(
                    iconKey: habit.iconKey,
                    icon: AppIcons.forKey(habit.iconKey),
                    size: 34,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: k.text.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('EEEE, d MMM').format(day),
                          style: k.text.caption.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: k.colors.outline),
            const SizedBox(height: 6),

            // Always a new note. It used to open the day's one note for
            // editing once there was one, so a second thought about the same
            // day could only be written over the first.
            _Action(
              icon: notes.isEmpty
                  ? Icons.sticky_note_2_outlined
                  : Icons.sticky_note_2,
              label: 'Add note',
              subtitle: switch (notes.length) {
                0 => 'How it went, or why it did not',
                1 => '1 note on this day already',
                final n => '$n notes on this day already',
              },
              onTap: () {
                Navigator.of(context).pop();
                HabitNoteSheet.show(context, habit: habit, day: day);
              },
            ),

            _Action(
              icon: Icons.swap_vert,
              label: 'Arrange',
              subtitle: 'Drag them into order, right on Home',
              onTap: () {
                // Arranged where they live: Home's own list, handles on.
                Navigator.of(context).popUntil((r) => r.isFirst);
                homeTabRequests.value++;
                homeArrangeMode.value = true;
              },
            ),

            if (habit.isArchived)
              _Action(
                icon: Icons.play_arrow_outlined,
                label: 'Resume tracking',
                subtitle: 'Start scheduling it again from today',
                onTap: () {
                  state.restoreHabit(habit);
                  Navigator.of(context).pop();
                },
              )
            else
              _Action(
                icon: Icons.pause_circle_outline,
                label: 'Discontinue',
                subtitle: 'Stops from today; past days still count',
                onTap: () {
                  state.archiveHabit(habit);
                  Navigator.of(context).pop();
                },
              ),

            _Action(
              icon: Icons.delete_outline,
              label: 'Delete',
              subtitle: 'Erases its history too',
              danger: true,
              onTap: () => _confirmDelete(context, state),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Deleting takes the history with it, which no other action here does — so
  /// it is the only one that asks first.
  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final k = context.k;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        title: Text('Delete ${habit.name}?', style: k.text.cardTitle),
        content: Text(
          'This removes every day it was logged, and the statistics change to '
          'match. Discontinuing keeps the record instead.',
          style: k.text.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: k.text.captionStrong.copyWith(
                color: k.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: k.text.captionStrong.copyWith(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.deleteHabit(habit);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final tint = danger ? k.colors.danger : k.colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: k.text.captionStrong.copyWith(
                        fontSize: 13.5,
                        color: tint,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: k.text.caption.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// One note on one habit: a new one, or an existing one to change.
class HabitNoteSheet extends StatefulWidget {
  const HabitNoteSheet({
    super.key,
    required this.habit,
    required this.day,
    this.index,
  });

  final Habit habit;
  final DateTime day;

  /// Which of the day's notes to edit, or null to write a new one.
  final int? index;

  static Future<void> show(
    BuildContext context, {
    required Habit habit,
    required DateTime day,
    int? index,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitNoteSheet(habit: habit, day: day, index: index),
    );
  }

  @override
  State<HabitNoteSheet> createState() => _HabitNoteSheetState();
}

class _HabitNoteSheetState extends State<HabitNoteSheet> {
  late final TextEditingController _note = TextEditingController(
    text: _existing ?? '',
  );

  /// The note being edited, or null when this is a new one.
  late final String? _existing = () {
    final i = widget.index;
    if (i == null) return null;
    final notes = context.read<AppState>().notesOn(widget.habit.id, widget.day);
    return i < notes.length ? notes[i] : null;
  }();

  bool get _editing => _existing != null;

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final state = context.read<AppState>();
    if (_editing) {
      await state.editNote(widget.habit, widget.day, widget.index!, _note.text);
    } else {
      await state.addNote(widget.habit, widget.day, _note.text);
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await context.read<AppState>().deleteNote(
      widget.habit,
      widget.day,
      widget.index!,
    );
    navigator.pop();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: k.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: k.colors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.habit.name, style: k.text.sectionTitle),
                Text(
                  DateFormat('EEEE, d MMM').format(widget.day),
                  style: k.text.caption,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _note,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: k.colors.primary,
                  style: k.text.bodyStrong.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ran 5k, felt easy. Or: skipped, calf sore.',
                    hintStyle: k.text.body.copyWith(color: k.colors.textMuted),
                    filled: true,
                    fillColor: k.colors.surfaceSoft,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        k.geometry.chipRadius,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        k.geometry.chipRadius,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        k.geometry.chipRadius,
                      ),
                      borderSide: BorderSide(
                        color: k.colors.accent,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: k.colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          k.geometry.chipRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      _editing ? 'Save note' : 'Add note',
                      style: k.text.captionStrong.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (_editing)
                  Center(
                    child: TextButton.icon(
                      onPressed: _delete,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: k.colors.danger,
                      ),
                      label: Text(
                        'Delete note',
                        style: k.text.captionStrong.copyWith(
                          fontSize: 13,
                          color: k.colors.danger,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
