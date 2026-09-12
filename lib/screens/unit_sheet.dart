import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';

/// Everything a habit can be measured in, one tap off the editor.
///
/// The new-habit page used to lay every unit out as a grid of chips. That
/// works for ten and stops working at twenty, and there is no natural end to
/// the list — chapters, lengths, cups, cigarettes. So the page keeps the three
/// goals that cover almost every habit and sends the rest here, where a long
/// list is allowed to be long because it is grouped and it is not in the way.
class UnitSheet extends StatefulWidget {
  const UnitSheet({super.key, required this.selected});

  final String selected;

  /// Returns the chosen unit, or null if the sheet was dismissed.
  static Future<String?> show(
    BuildContext context, {
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnitSheet(selected: selected),
    );
  }

  @override
  State<UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<UnitSheet> {
  late final TextEditingController _custom = TextEditingController(
    // Only prefilled when the habit already uses something off-list, which is
    // the one case where somebody is coming back to edit their own word.
    text: AppContent.habitUnits.contains(widget.selected)
        ? ''
        : widget.selected,
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _pick(String unit) => Navigator.of(context).pop(unit);

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
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
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  children: [
                    Text(AppContent.unitSheetTitle, style: k.text.sectionTitle),
                    const SizedBox(height: 14),

                    // First, and on its own: most habits are not measured at
                    // all. It used to be a chip on the editor page beside two
                    // units, which put "not measured" and "minutes" on the
                    // same footing — they are not the same kind of answer.
                    _PlainRow(
                      selected: widget.selected.isEmpty,
                      onTap: () => _pick(''),
                    ),
                    const SizedBox(height: 18),

                    for (final entry in AppContent.unitGroups.entries) ...[
                      Text(
                        entry.key.toUpperCase(),
                        style: k.text.captionStrong.copyWith(
                          fontSize: 10.5,
                          letterSpacing: 1.1,
                          color: k.colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final unit in entry.value)
                            _UnitChip(
                              label: unit,
                              selected: unit == widget.selected,
                              onTap: () => _pick(unit),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      AppContent.unitCustomLabel.toUpperCase(),
                      style: k.text.captionStrong.copyWith(
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                        color: k.colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _custom,
                            textCapitalization: TextCapitalization.none,
                            decoration: InputDecoration(
                              hintText: AppContent.unitCustomHint,
                              hintStyle: k.text.caption,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: k.colors.surfaceSoft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  k.geometry.innerRadius,
                                ),
                                borderSide: BorderSide(color: k.colors.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  k.geometry.innerRadius,
                                ),
                                borderSide: BorderSide(color: k.colors.outline),
                              ),
                            ),
                            style: k.text.body,
                            onSubmitted: (value) {
                              final unit = value.trim();
                              if (unit.isNotEmpty) _pick(unit);
                            },
                          ),
                        ),
                        const SizedBox(width: 9),
                        // Deliberately a separate press rather than accepting
                        // on every keystroke: half-typed words would otherwise
                        // arrive as the habit's unit.
                        IconButton(
                          onPressed: () {
                            final unit = _custom.text.trim();
                            if (unit.isNotEmpty) _pick(unit);
                          },
                          icon: Icon(
                            Icons.check_circle,
                            color: k.colors.accent,
                          ),
                        ),
                      ],
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

/// "Just do it" — a habit with no number in it.
class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Material(
      color: selected ? k.colors.accent : k.colors.surfaceSoft,
      borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(k.geometry.innerRadius),
            border: Border.all(
              color: selected ? k.colors.accent : k.colors.outline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 19,
                color: selected ? Colors.white : k.colors.primary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppContent.goalJustDoIt,
                      style: k.text.bodyStrong.copyWith(
                        fontSize: 14,
                        color: selected ? Colors.white : k.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppContent.unitPlainBody,
                      style: k.text.caption.copyWith(
                        fontSize: 11.5,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : k.colors.textSecondary,
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
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? k.colors.accent : k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(k.geometry.pillRadius),
          border: Border.all(
            color: selected ? k.colors.accent : k.colors.outline,
          ),
        ),
        child: Text(
          label,
          style: k.text.captionStrong.copyWith(
            fontSize: 13,
            color: selected ? Colors.white : k.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
