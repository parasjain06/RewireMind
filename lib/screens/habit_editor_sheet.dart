import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/habit.dart';
import '../models/habit_preset.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'reminder_editor_sheet.dart';
import 'unit_sheet.dart';

/// Create or edit a habit.
///
/// Pass [habit] to edit an existing one; omit it to create. Returns the saved
/// habit, or null if dismissed.
class HabitEditorSheet extends StatefulWidget {
  const HabitEditorSheet({super.key, this.habit, this.preset, this.startOn});

  final Habit? habit;

  /// Prefills the form from a library preset when creating. Ignored when
  /// [habit] is given, since editing already has its own values.
  final HabitPreset? preset;

  /// The day a new habit should begin. Null means today; ignored when
  /// editing, which keeps the habit's own start date.
  final DateTime? startOn;

  static Future<Habit?> show(
    BuildContext context, {
    Habit? habit,
    HabitPreset? preset,
    DateTime? startOn,
  }) {
    return showModalBottomSheet<Habit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          HabitEditorSheet(habit: habit, preset: preset, startOn: startOn),
    );
  }

  @override
  State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.habit?.name ?? widget.preset?.name ?? '',
  );
  late final TextEditingController _target = TextEditingController(
    text: _trim(widget.habit?.target ?? widget.preset?.target ?? 1),
  );

  late String _iconKey =
      widget.habit?.iconKey ??
      widget.preset?.iconKey ??
      AppIcons.habitKeys.first;

  /// The habit's colour on the board. Null until somebody picks one, which
  /// leaves it following the theme's accent for its icon.
  late int? _colour = widget.habit?.colorValue;
  late String _unit = widget.habit?.unit ?? widget.preset?.unit ?? '';
  late HabitKind _kind =
      widget.habit?.kind ?? widget.preset?.kind ?? HabitKind.build;
  late Set<int> _days = {
    ...(widget.habit?.activeWeekdays ?? const {1, 2, 3, 4, 5, 6, 7}),
  };

  String? _error;

  bool get _isEditing => widget.habit != null;

  static String _trim(double n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickUnit() async {
    final picked = await UnitSheet.show(context, selected: _unit);
    if (picked != null && mounted) setState(() => _unit = picked);
  }

  Future<void> _pickIcon() => _openPicker(
    AppContent.editorIconLabel,
    (setSheet) => _IconPicker(
      selected: _iconKey,
      onSelect: (key) {
        setState(() => _iconKey = key);
        setSheet();
      },
    ),
  );

  Future<void> _pickColour() => _openPicker(
    AppContent.colourLabel,
    (setSheet) => _ColourPicker(
      selected: _colour,
      onSelect: (value) {
        setState(() => _colour = value);
        setSheet();
      },
    ),
  );

  /// One sheet, two uses. Both pickers are a title and a grid; the only thing
  /// that differs is which grid.
  Future<void> _openPicker(
    String title,
    Widget Function(VoidCallback rebuild) body,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) =>
            _PickerSheet(title: title, child: body(() => setSheet(() {}))),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    // A cut-back habit is always a single daily tick — there is no amount
    // to measure, only whether you stayed on track.
    final isQuit = _kind == HabitKind.quit;
    final unit = isQuit ? '' : _unit;
    // A habit with no unit is the yes/no kind, and its target is one — the
    // number field is hidden in that case, so whatever is left in it from
    // before must not be allowed to become the goal.
    final target = (isQuit || unit.isEmpty)
        ? 1.0
        : (double.tryParse(_target.text.trim()) ?? 0);

    final problem = switch (true) {
      _ when name.isEmpty => AppContent.editorNameRequired,
      _ when target <= 0 => AppContent.editorTargetRequired,
      _ when _days.isEmpty => AppContent.editorDaysRequired,
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final state = context.read<AppState>();
    final Habit saved;
    if (_isEditing) {
      saved = widget.habit!.copyWith(
        name: name,
        iconKey: _iconKey,
        target: target,
        unit: unit,
        kind: _kind,
        activeWeekdays: _days,
        colorValue: _colour,
        clearColor: _colour == null,
      );
      await state.updateHabit(saved);
    } else {
      saved = await state.addHabit(
        startOn: widget.startOn,
        name: name,
        iconKey: _iconKey,
        target: target,
        unit: unit,
        kind: _kind,
        activeWeekdays: _days,
        colorValue: _colour,
      );
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop(saved);

    // Only for a brand new habit, and only after the sheet is out of the way,
    // so the question arrives on the screen behind it rather than on top of a
    // form that is already closing.
    if (!_isEditing && navigator.mounted) {
      await offerReminderFor(navigator.context, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  children: [
                    Text(
                      _isEditing
                          ? AppContent.editorEditTitle
                          : AppContent.editorNewTitle,
                      style: k.text.sectionTitle,
                    ),
                    const SizedBox(height: 16),
                    _FieldLabel(AppContent.editorKindLabel),
                    _KindPicker(
                      selected: _kind,
                      onSelect: (kind) => setState(() => _kind = kind),
                    ),
                    const SizedBox(height: 13),
                    _FieldLabel(AppContent.editorNameLabel),
                    _TextBox(
                      controller: _name,
                      hint: AppContent.editorNameHint,
                      // Not focused on open. The keyboard covered the lower
                      // half of the sheet the moment it appeared, so the icon
                      // picker, the goal and the days were all behind it and
                      // the first thing anybody had to do was scroll to find
                      // out what they were. Tap the field and it comes up.
                      onChanged: (_) => _clearError(),
                    ),
                    const SizedBox(height: 13),
                    // Two rows, not one. They were behind a single "Look"
                    // button, which hid the fact that the colour is not
                    // decoration — it is the hue this habit wears on the board
                    // and in the progress breakdown, and it is the only thing
                    // telling eight habits apart there. A row that says so is
                    // worth the line it costs.
                    _PickerRow(
                      label: AppContent.editorIconRow,
                      body: AppContent.editorIconBody,
                      onTap: _pickIcon,
                      trailing: _IconBubble(iconKey: _iconKey, colour: _colour),
                    ),
                    const SizedBox(height: 9),
                    _PickerRow(
                      label: AppContent.editorColourRow,
                      body: AppContent.editorColourBody,
                      onTap: _pickColour,
                      trailing: _ColourBubble(
                        iconKey: _iconKey,
                        colour: _colour,
                      ),
                    ),
                    const SizedBox(height: 13),
                    if (_kind == HabitKind.build) ...[
                      _FieldLabel(AppContent.editorGoalLabel),
                      // One control rather than three chips and a door to the
                      // rest. There is no end to the list of units — kilos,
                      // lengths, chapters, cigarettes — so a row of chips
                      // either grows forever or hides most of them behind a
                      // fourth chip nobody presses.
                      _PickerRow(
                        label: _unit.isEmpty ? AppContent.goalJustDoIt : _unit,
                        body: _unit.isEmpty
                            ? AppContent.unitPlainBody
                            : AppContent.unitSheetTitle,
                        onTap: _pickUnit,
                        trailing: Icon(
                          Icons.expand_more,
                          size: 20,
                          color: k.colors.textMuted,
                        ),
                      ),
                      // The number only means anything once there is a unit
                      // for it to count. "Just do it" is the habit itself.
                      if (_unit.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            SizedBox(
                              width: 92,
                              child: _TextBox(
                                controller: _target,
                                hint: '1',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                textAlign: TextAlign.center,
                                onChanged: (_) => _clearError(),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Text(
                              '$_unit a day',
                              style: k.text.body.copyWith(
                                color: k.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: k.colors.accent,
                          ),
                          const SizedBox(width: 7),
                          Text(AppContent.quitGoalLabel, style: k.text.body),
                        ],
                      ),
                    const SizedBox(height: 13),
                    _FieldLabel(AppContent.editorRepeatLabel),
                    _WeekdayPicker(
                      selected: _days,
                      onChanged: (days) => setState(() {
                        _days = days;
                        _clearError();
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              // The primary action stays pinned so it is reachable however
              // tall the form gets.
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 15,
                              color: k.colors.danger,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _error!,
                                style: k.text.caption.copyWith(
                                  color: k.colors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _PrimaryButton(
                      label: _isEditing
                          ? AppContent.editorSave
                          : AppContent.editorCreate,
                      onTap: _save,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        AppContent.editorCancel,
                        style: k.text.bodyStrong.copyWith(
                          color: k.colors.textSecondary,
                        ),
                      ),
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

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }
}

// ---------------------------------------------------------------------------
// Field pieces
// ---------------------------------------------------------------------------

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
    this.keyboardType,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
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
          horizontal: 13,
          vertical: 11,
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

/// Build vs cut back. This is the one choice that changes how the habit
/// reads everywhere else, so it comes first.
class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.selected, required this.onSelect});

  final HabitKind selected;
  final ValueChanged<HabitKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    Widget option(HabitKind kind, String label, IconData icon) {
      final isSelected = kind == selected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(kind),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected ? k.colors.primary : k.colors.surfaceSoft,
              borderRadius: BorderRadius.circular(k.geometry.chipRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : k.colors.accent,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: k.text.captionStrong.copyWith(
                      fontSize: 12.5,
                      color: isSelected ? Colors.white : k.colors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(HabitKind.build, AppContent.editorKindBuild, Icons.trending_up),
        const SizedBox(width: 8),
        option(HabitKind.quit, AppContent.editorKindQuit, Icons.block),
      ],
    );
  }
}

/// A labelled row that opens something.
///
/// The shape shared by the goal, the icon and the colour: what it is set to on
/// the left, what that means underneath, and the thing itself on the right.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.body,
    required this.onTap,
    required this.trailing,
  });

  final String label;
  final String body;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Material(
      color: k.colors.surfaceSoft,
      borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(k.geometry.innerRadius),
            border: Border.all(color: k.colors.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: k.text.bodyStrong.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 1),
                    Text(body, style: k.text.caption.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// The chosen icon, on the chosen colour.
class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.iconKey, required this.colour});

  final String iconKey;
  final int? colour;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final accent = k.colors.accentFor(iconKey);
    final tint = colour == null ? accent.background : Color(colour!);
    final ink = colour == null ? accent.foreground : Colors.white;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      child: Icon(AppIcons.forKey(iconKey), size: 18, color: ink),
    );
  }
}

/// The chosen colour, as a plain swatch.
///
/// No icon in it, deliberately: this row is about the colour, and the colour
/// is not the habit's face — it is the hue it wears on the board and in the
/// progress breakdown, where it is the only thing telling eight habits apart.
class _ColourBubble extends StatelessWidget {
  const _ColourBubble({required this.iconKey, required this.colour});

  final String iconKey;
  final int? colour;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final shown = colour == null
        ? k.colors.accentFor(iconKey).foreground
        : Color(colour!);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: shown,
        shape: BoxShape.circle,
        border: Border.all(color: k.colors.outline),
      ),
    );
  }
}

/// A titled bottom sheet with one picker in it.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
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
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                children: [
                  Text(title, style: k.text.sectionTitle),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final key in AppIcons.habitKeys)
          () {
            final accent = k.colors.accentFor(key);
            final isSelected = key == selected;
            return GestureDetector(
              onTap: () => onSelect(key),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? k.colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  AppIcons.forKey(key),
                  size: 18,
                  color: accent.foreground,
                ),
              ),
            );
          }(),
      ],
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
                      height: 34,
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
        Row(
          children: [
            quick(AppContent.editorEveryDay, {1, 2, 3, 4, 5, 6, 7}),
            const SizedBox(width: 8),
            quick(AppContent.editorWeekdays, {1, 2, 3, 4, 5}),
          ],
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: k.colors.primary,
      borderRadius: BorderRadius.circular(k.geometry.pillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(
              label,
              style: k.text.cardTitle.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// The habit's colour on the board.
///
/// Ten swatches and nothing else — no wheel, no hex field. The board only
/// works if habits are told apart at a glance, and a free choice of sixteen
/// million colours is how you end up with two greens you cannot distinguish.
class _ColourPicker extends StatelessWidget {
  const _ColourPicker({required this.selected, required this.onSelect});

  /// Null means "whatever the icon's accent is", which is what a habit that
  /// has never been given a colour keeps.
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final value in AppContent.habitColours)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                // Tapping the one already chosen puts it back to the theme's
                // own colour, so there is a way out of having picked.
                onTap: () => onSelect(selected == value ? null : value),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(value),
                    shape: BoxShape.circle,
                    border: selected == value
                        ? Border.all(color: k.colors.primary, width: 2.5)
                        : null,
                  ),
                  child: selected == value
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
