import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../content/app_content.dart';
import '../content/notification_content.dart';
import '../content/reminder_library.dart';
import '../models/habit.dart';
import '../models/reminder.dart';
import '../screens/notifications_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';

/// Write one reminder: what it says, when it arrives, and which days.
///
/// The preview at the top is the point of the screen — tokens like `{habit}`
/// mean nothing until you can see what they turn into.
class ReminderEditorSheet extends StatefulWidget {
  const ReminderEditorSheet({
    super.key,
    this.reminder,
    this.preset,
    this.habitId,
    this.initialTime,
  });

  /// The reminder being edited, or null when creating.
  final Reminder? reminder;

  /// Prefills the wording from the library. Ignored when [reminder] is given.
  final ReminderPreset? preset;

  /// Scopes a new reminder to one habit. Ignored when editing.
  final String? habitId;

  /// The time already chosen for a new reminder, from whoever opened this.
  /// Ignored when editing, which keeps the reminder's own time.
  final TimeOfDayValue? initialTime;

  static Future<void> show(
    BuildContext context, {
    Reminder? reminder,
    ReminderPreset? preset,
    String? habitId,
    TimeOfDayValue? initialTime,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderEditorSheet(
        reminder: reminder,
        preset: preset,
        habitId: habitId,
        initialTime: initialTime,
      ),
    );
  }

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  static const _uuid = Uuid();

  late final TextEditingController _text = TextEditingController(
    text: widget.reminder?.text ?? widget.preset?.text ?? '',
  );

  late TimeOfDayValue _time =
      widget.reminder?.time ??
      widget.initialTime ??
      const TimeOfDayValue(8, 30);
  late Set<int> _days = {...(widget.reminder?.weekdays ?? Reminder.everyDay)};

  /// Always true for a new reminder: the app stays quiet once the thing
  /// it was chasing is done, and there is no longer a switch saying
  /// otherwise. Kept as a field so an older reminder that was saved with
  /// it off is not silently changed by being opened.
  late final bool _skipWhenDone = widget.reminder?.skipWhenDone ?? true;

  bool get _isEditing => widget.reminder != null;

  @override
  void dispose() {
    _text.dispose();
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                  children: [
                    // A titled row with a way out of it. The sheet could only
                    // be left by dragging it down or pressing the page behind
                    // it — both of which somebody has to already know, and
                    // neither of which is on the screen.
                    Row(
                      children: [
                        _BackButton(onTap: () => Navigator.of(context).pop()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isEditing
                                ? NotificationContent.editorEditTitle
                                : NotificationContent.editorNewTitle,
                            style: k.text.sectionTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Shown first, because it is what the reminder will
                    // actually look like.
                    _Preview(
                      text: _text.text,
                      withQuote: context
                          .watch<AppState>()
                          .notifyPrefs
                          .appendQuote,
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel(NotificationContent.editorTextLabel),
                    _TextBox(
                      controller: _text,
                      hint: NotificationContent.editorTextHint,
                      // Not focused on open. The keyboard came up with the
                      // sheet and covered the time, the days and the button —
                      // so the first thing anybody had to do was dismiss it to
                      // find out what else was there.
                      autofocus: false,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),

                    _FieldLabel(NotificationContent.editorTimeLabel),
                    _TimeField(time: _time, onTap: _pickTime),
                    const SizedBox(height: 18),

                    _FieldLabel(NotificationContent.editorDaysLabel),
                    _WeekdayPicker(
                      selected: _days,
                      onChanged: (days) => setState(() => _days = days),
                    ),
                    const SizedBox(height: 10),

                    // Said, not asked. A reminder chasing something you
                    // finished at six is the fastest way to get notifications
                    // switched off altogether, so it simply does not — and a
                    // switch offering to do the wrong thing is a switch with
                    // one sensible setting.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 15,
                          color: k.colors.textMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            NotificationContent.quietWhenDone,
                            style: k.text.caption.copyWith(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _PrimaryButton(
                      label: _isEditing ? 'Save' : 'Add reminder',
                      onTap: _canSave ? _save : null,
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _delete,
                        child: Text(
                          'Delete reminder',
                          style: k.text.captionStrong.copyWith(
                            color: k.colors.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A reminder with no title would arrive as a blank line in the shade.
  bool get _canSave => _text.text.trim().isNotEmpty && _days.isNotEmpty;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute),
      // The clock face, and twelve-hour whatever the device locale prefers —
      // a reminder list full of 20:30 reads like a train timetable.
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _time = TimeOfDayValue(picked.hour, picked.minute));
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final reminder =
        (widget.reminder ??
                Reminder(
                  id: _uuid.v4(),
                  habitId: widget.habitId,
                  text: '',
                  time: _time,
                ))
            .copyWith(
              text: _text.text.trim(),
              time: _time,
              weekdays: _days,
              skipWhenDone: _skipWhenDone,
              enabled: true,
            );

    await state.saveReminder(reminder);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final state = context.read<AppState>();
    await state.deleteReminder(widget.reminder!.id);
    if (mounted) Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------

/// The way back out of a sheet.
///
/// An arrow rather than a cross: this sheet is opened from a list you were
/// already looking at, and back is where it returns you.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: k.colors.surfaceSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.arrow_back, size: 18, color: k.colors.primary),
        ),
      ),
    );
  }
}

/// What the reminder will look like in the shade.
class _Preview extends StatelessWidget {
  const _Preview({required this.text, required this.withQuote});

  final String text;
  final bool withQuote;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final shown = text.trim().isEmpty ? 'Your reminder' : text;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        border: Border.all(color: k.colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: k.colors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                AppContent.appName,
                style: k.text.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: k.colors.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                NotificationContent.editorPreviewLabel,
                style: k.text.caption.copyWith(
                  fontSize: 10,
                  color: k.colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(shown, style: k.text.captionStrong.copyWith(fontSize: 14)),
          if (withQuote) ...[
            const SizedBox(height: 2),
            Text(
              NotificationContent.quoteFor(DateTime.now()),
              style: k.text.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.time, required this.onTap});

  final TimeOfDayValue time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(k.geometry.chipRadius),
        ),
        child: Row(
          children: [
            Text(
              '$h:${time.minute.toString().padLeft(2, '0')}',
              style: k.text.statValue.copyWith(
                fontSize: 30,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                time.meridiem,
                style: k.text.captionStrong.copyWith(
                  fontSize: 15,
                  color: k.colors.primary,
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.schedule, size: 20, color: k.colors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared form pieces, matching the habit editor's look.

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: k.text.captionStrong.copyWith(fontSize: 12)),
    );
  }
}

class _TextBox extends StatelessWidget {
  const _TextBox({
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return TextField(
      controller: controller,
      maxLines: 2,
      minLines: 1,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
      cursorColor: k.colors.primary,
      style: k.text.bodyStrong.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: k.text.body.copyWith(color: k.colors.textMuted),
        filled: true,
        fillColor: k.colors.surfaceSoft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(k.geometry.chipRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(k.geometry.chipRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(k.geometry.chipRadius),
          borderSide: BorderSide(color: k.colors.accent, width: 1.6),
        ),
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    Widget quick(String label, Set<int> days) {
      final active =
          selected.length == days.length && selected.every(days.contains);
      return GestureDetector(
        onTap: () => onChanged({...days}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? k.colors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(k.geometry.pillRadius),
            border: Border.all(color: k.colors.outline),
          ),
          child: Text(
            label,
            style: k.text.captionStrong.copyWith(
              fontSize: 11,
              color: active ? k.colors.primary : k.colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var day = 1; day <= 7; day++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: day == 7 ? 0 : 6),
                  child: GestureDetector(
                    onTap: () {
                      final next = {...selected};
                      if (!next.remove(day)) next.add(day);
                      onChanged(next);
                    },
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected.contains(day)
                            ? k.colors.primary
                            : k.colors.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        AppContent.weekdayInitials[day - 1],
                        style: k.text.captionStrong.copyWith(
                          color: selected.contains(day)
                              ? Colors.white
                              : k.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            quick('Every day', Reminder.everyDay),
            quick('Weekdays', Reminder.weekdaysOnly),
            quick('Weekends', Reminder.weekendsOnly),
          ],
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final enabled = onTap != null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? k.colors.primary : k.colors.accentTrack,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(k.geometry.chipRadius),
          ),
        ),
        child: Text(
          label,
          style: k.text.captionStrong.copyWith(
            fontSize: 14,
            color: enabled ? Colors.white : k.colors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Offers a reminder for a habit that has just been created.
///
/// Asked at the moment the habit is made, because that is when the user knows
/// when they intend to do it — going back later to add one is a step almost
/// nobody takes.
Future<void> offerReminderFor(BuildContext context, Habit habit) async {
  final k = context.k;
  final state = context.read<AppState>();

  final wanted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: k.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
      ),
      title: Text('Remind you?', style: k.text.cardTitle),
      content: Text(
        'Want a nudge for ${habit.name} at a time that suits you?',
        style: k.text.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Not now',
            style: k.text.captionStrong.copyWith(
              fontSize: 13,
              color: k.colors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Add reminder',
            style: k.text.captionStrong.copyWith(
              fontSize: 13,
              color: k.colors.primary,
            ),
          ),
        ),
      ],
    ),
  );

  if (wanted != true || !context.mounted) return;

  // Saying yes has to be enough. If reminders are off, turn them on here
  // rather than sending the user to Profile to find a switch.
  if (!state.notifyPrefs.enabled) {
    final granted = await state.enableNotifications();
    if (!context.mounted) return;
    if (!granted) {
      // A dead end used to be the whole of this branch: a message saying
      // permission was refused, and no way to do anything about it. The
      // reminders screen is where the master switch and the wording about
      // background limits are, so that is where somebody who just asked for a
      // reminder should be standing.
      await showAppSnackBar(
        context,
        message: NotificationContent.permissionDenied,
        duration: const Duration(seconds: 4),
      );
      if (context.mounted) await NotificationsScreen.open(context);
      return;
    }
  }

  if (!context.mounted) return;

  // The dialog offered "a time that suits you", so the next thing to happen
  // is the clock. It used to be the editor with 8:30 already in it, which
  // meant somebody could say yes to a reminder, press Save, and end up with a
  // time they never chose — the one question the offer promised to ask was
  // the one it skipped.
  final picked = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 8, minute: 30),
    helpText: AppContent.reminderPickTime,
    initialEntryMode: TimePickerEntryMode.dial,
    // Twelve-hour with an AM/PM toggle whatever the device locale prefers: a
    // reminder list full of 20:30 reads like a train timetable.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: child!,
    ),
  );
  if (picked == null || !context.mounted) return;

  await ReminderEditorSheet.show(
    context,
    habitId: habit.id,
    initialTime: TimeOfDayValue(picked.hour, picked.minute),
    preset: ReminderPreset(
      NotificationContent.forHabit(
        ReminderLibrary.habitPresets.first.text,
        habit.name,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------

/// Deletes a reminder from wherever it is listed.
///
/// No confirmation, but an undo: a reminder is a sentence and a time, so
/// asking first costs more than getting it back does.
class DeleteReminderButton extends StatelessWidget {
  const DeleteReminderButton({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return IconButton(
      onPressed: () async {
        final state = context.read<AppState>();
        // Captured before the await: this button lives inside the row that is
        // about to be removed from the tree.
        final messengerContext = context;
        await state.deleteReminder(reminder.id);
        if (!messengerContext.mounted) return;

        await showAppSnackBar(
          messengerContext,
          message: 'Reminder deleted',
          actionLabel: 'Undo',
          onAction: () => state.saveReminder(reminder),
        );
      },
      icon: Icon(Icons.delete_outline, size: 19, color: k.colors.textMuted),
      tooltip: 'Delete reminder',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }
}
