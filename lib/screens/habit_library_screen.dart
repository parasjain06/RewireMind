import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/habit_library.dart';
import '../models/habit_preset.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/k_card.dart';
import 'habit_editor_sheet.dart';
import 'reminder_editor_sheet.dart';
import '../content/premium_content.dart';
import '../models/premium.dart';
import 'premium_screen.dart';

/// Browse ready-made habits by category and add one in a tap.
///
/// Tapping the row opens the editor prefilled (change the goal first); tapping
/// the + adds it straight away with the preset's defaults.
class HabitLibraryScreen extends StatefulWidget {
  const HabitLibraryScreen({super.key, this.startOn});

  /// The day habits added from here should begin. Null means today.
  final DateTime? startOn;

  static Future<void> open(BuildContext context, {DateTime? startOn}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HabitLibraryScreen(startOn: startOn)),
    );
  }

  @override
  State<HabitLibraryScreen> createState() => _HabitLibraryScreenState();
}

class _HabitLibraryScreenState extends State<HabitLibraryScreen> {
  HabitCategory _category = HabitCategory.popular;

  /// A preset counts as added when a habit already uses that name.
  bool _isAdded(AppState state, HabitPreset preset) => state.habits.any(
    (h) => h.name.toLowerCase() == preset.name.toLowerCase(),
  );

  /// Removes the habit this preset created.
  ///
  /// Kept rather than deleted when there is anything logged against it —
  /// discontinuing leaves the record intact, so past streaks and rates stay
  /// true to what actually happened, and the row goes back to offering the
  /// preset either way.
  /// True when there is room on the free tier; otherwise shows the page and
  /// returns false.
  Future<bool> _roomForOneMore() async {
    final state = context.read<AppState>();
    if (state.canAddHabit) return true;
    await PremiumScreen.open(
      context,
      note: PremiumContent.lockedHabits(kFreeHabitLimit),
    );
    return false;
  }

  Future<void> _remove(HabitPreset preset) async {
    final state = context.read<AppState>();
    final habit = state.everyHabit.firstWhere(
      (h) => h.name.toLowerCase() == preset.name.toLowerCase(),
      orElse: () => state.everyHabit.first,
    );
    if (habit.name.toLowerCase() != preset.name.toLowerCase()) return;

    // Anything logged against it and the record is worth keeping, so the
    // habit is discontinued rather than deleted — past streaks and rates stay
    // true to what happened. A habit nobody ever ticked has nothing to keep.
    if (state.hasHistory(habit.id)) {
      await state.archiveHabit(habit);
    } else {
      await state.deleteHabit(habit);
    }

    if (!mounted) return;
    await showAppSnackBar(context, message: HabitLibrary.removed(preset.name));
  }

  Future<void> _quickAdd(HabitPreset preset) async {
    final state = context.read<AppState>();
    if (!await _roomForOneMore()) return;

    final habit = await state.addHabit(
      name: preset.name,
      iconKey: preset.iconKey,
      target: preset.target,
      unit: preset.unit,
      kind: preset.kind,
      startOn: widget.startOn,
    );

    if (!mounted) return;
    await showAppSnackBar(
      context,
      message: '${preset.name} ${HabitLibrary.addedToast}',
      duration: const Duration(milliseconds: 1600),
    );

    // Asked now, while the user is still thinking about when they will do it.
    if (!mounted) return;
    await offerReminderFor(context, habit);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final presets = HabitLibrary.forCategory(_category);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: k.colors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            HabitLibrary.screenTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: Column(
          children: [
            _CategoryBar(
              selected: _category,
              onSelect: (c) => setState(() => _category = c),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                k.geometry.screenPadding,
                8,
                k.geometry.screenPadding,
                2,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  HabitLibrary.blurbs[_category] ?? '',
                  style: k.text.caption.copyWith(fontSize: 11),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  k.geometry.screenPadding,
                  6,
                  k.geometry.screenPadding,
                  76,
                ),
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (context, i) {
                  final preset = presets[i];
                  final added = _isAdded(state, preset);
                  return _PresetRow(
                    preset: preset,
                    added: added,
                    onAdd: added ? null : () => _quickAdd(preset),
                    onRemove: added ? () => _remove(preset) : null,
                    onCustomise: () async {
                      if (!await _roomForOneMore()) return;
                      if (!context.mounted) return;
                      await HabitEditorSheet.show(
                        context,
                        preset: preset,
                        startOn: widget.startOn,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _CustomHabitButton(
          onTap: () async {
            if (!await _roomForOneMore()) return;
            if (!context.mounted) return;
            await HabitEditorSheet.show(context, startOn: widget.startOn);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Identifies the scrolling category strip, so tests can drag it to reach
/// categories that start off-screen.
const Key categoryBarKey = ValueKey('habit-library-category-bar');

/// Horizontally scrolling category pills.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelect});

  final HabitCategory selected;
  final ValueChanged<HabitCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        key: categoryBarKey,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: k.geometry.screenPadding),
        itemCount: HabitLibrary.order.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final category = HabitLibrary.order[i];
          final isSelected = category == selected;
          final foreground = isSelected ? Colors.white : k.colors.textSecondary;

          return GestureDetector(
            onTap: () => onSelect(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: isSelected ? k.colors.primary : k.colors.surface,
                borderRadius: BorderRadius.circular(k.geometry.pillRadius),
                boxShadow: isSelected ? null : k.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    HabitLibrary.icons[category],
                    size: 13,
                    color: isSelected ? Colors.white : k.colors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    HabitLibrary.labels[category] ?? '',
                    style: k.text.captionStrong.copyWith(
                      fontSize: 11,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.added,
    required this.onAdd,
    required this.onRemove,
    required this.onCustomise,
  });

  final HabitPreset preset;
  final bool added;

  /// Takes the habit this preset created back off the list. Only offered for
  /// one that is already added — a tick with no way past it is a dead end on
  /// the one screen whose whole job is changing what you track.
  final VoidCallback? onRemove;

  /// Null once the habit is already in the user's list.
  final VoidCallback? onAdd;
  final VoidCallback onCustomise;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      onTap: added ? null : onCustomise,
      child: Row(
        children: [
          IconChip(
            iconKey: preset.iconKey,
            icon: AppIcons.forKey(preset.iconKey),
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.name,
                  style: k.text.cardTitle.copyWith(fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  preset.goalLabel,
                  style: k.text.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (added)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 17, color: k.colors.accent),
                const SizedBox(width: 4),
                Text(
                  HabitLibrary.added,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 11,
                    color: k.colors.accent,
                  ),
                ),
                const SizedBox(width: 2),
                _RemoveButton(onTap: onRemove!),
              ],
            )
          else
            _AddButton(onTap: onAdd!),
        ],
      ),
    );
  }
}

/// Takes an added habit back off the list.
///
/// Discontinuing rather than deleting where there is history to lose: a habit
/// somebody tracked for three weeks and then removed from this screen still
/// has three weeks in it, and silently binning that is not what "remove" is
/// understood to mean. One that was never logged is simply deleted.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(Icons.close, size: 17, color: k.colors.textMuted),
      tooltip: HabitLibrary.remove,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // Filled, not tinted. A pale plus on a pale disc read as a control that
    // had already been used — which on a row that says "add this" is the one
    // impression it must not give.
    return Material(
      color: k.colors.accent,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.add, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _CustomHabitButton extends StatelessWidget {
  const _CustomHabitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: k.colors.primary,
      borderRadius: BorderRadius.circular(k.geometry.pillRadius),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 15, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                HabitLibrary.customButton,
                style: k.text.captionStrong.copyWith(
                  fontSize: 12.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
