import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ============================================================================
/// GROUPED SETTINGS
/// ============================================================================
/// The shape every settings screen worth copying uses: a small uppercase
/// heading, then one card holding several rows divided by hairlines.
///
/// Account, Help and About were each a stack of separate floating cards, one
/// per row. That reads as a list of unrelated announcements — nothing says
/// which rows belong together, every row carries the same visual weight as
/// every other, and a screen of eight of them has eight shadows on it. A group
/// says "these four are the same kind of thing" for free, and costs a line of
/// 11pt text.
/// ============================================================================

/// A titled group of rows, drawn as one card.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  /// The small heading above the card. Omitted for a group that needs none —
  /// the identity block at the top of a screen, for instance.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
            child: Text(
              title!.toUpperCase(),
              style: k.text.captionStrong.copyWith(
                fontSize: 10.5,
                letterSpacing: 1.1,
                color: k.colors.textMuted,
              ),
            ),
          ),
        DecoratedBox(
          decoration: k.cardDecoration,
          // Clipped so a row's ink ripple stops at the card's corners rather
          // than squaring them off on the way past.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(k.geometry.cardRadius),
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      color: k.colors.outline,
                    ),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row in a [SettingsGroup]: an icon, a label, and somewhere to go.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.onTap,
    this.external = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// A second line under the label. Kept to a phrase — a settings row that
  /// needs a sentence is a settings row in the wrong place.
  final String? subtitle;

  /// Shown at the right instead of a chevron: a count, a date, a version.
  final String? value;

  final VoidCallback? onTap;

  /// Draws the "leaves the app" arrow rather than the "goes deeper" chevron.
  /// The difference matters: one of them loses your place.
  final bool external;

  /// Red, for the row that cannot be undone.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ink = destructive ? k.colors.danger : k.colors.textPrimary;
    final tint = destructive ? k.colors.danger : k.colors.primary;

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: k.text.bodyStrong.copyWith(fontSize: 14, color: ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: k.text.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                value!,
                style: k.text.captionStrong.copyWith(
                  fontSize: 12.5,
                  color: k.colors.textSecondary,
                ),
              ),
            )
          else if (onTap != null)
            Icon(
              external ? Icons.north_east : Icons.chevron_right,
              size: external ? 17 : 20,
              color: k.colors.textMuted,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// A row that answers a question when you press it, and says nothing until
/// you do. Six of these are worth more than a page of prose nobody reads.
class SettingsQuestion extends StatefulWidget {
  const SettingsQuestion({
    super.key,
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  State<SettingsQuestion> createState() => _SettingsQuestionState();
}

class _SettingsQuestionState extends State<SettingsQuestion>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: k.text.bodyStrong.copyWith(fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Turns rather than swaps: the arrow is the same object
                    // before and after, which is what makes it read as the
                    // row opening rather than as a different row.
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 170),
                      child: Icon(
                        Icons.expand_more,
                        size: 19,
                        color: k.colors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (_open) ...[
                  const SizedBox(height: 7),
                  Text(
                    widget.answer,
                    style: k.text.body.copyWith(fontSize: 12.5, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
