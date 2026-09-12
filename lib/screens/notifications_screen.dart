import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/notification_content.dart';
import '../content/reminder_library.dart';
import '../models/habit.dart';
import '../models/reminder.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_background.dart';
import '../widgets/k_card.dart';
import 'reminder_editor_sheet.dart';

/// Temporary review aid: a "send now" button on each reminder, so it can be
/// seen without waiting for its hour. Set to false once signed off.
const bool kNotificationTestPanel = bool.fromEnvironment('DEV_TOOLS');

/// The user's reminders, in the order of the day.
///
/// The app decides nothing here: what each one says, when it arrives and how
/// many there are is entirely this list.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final prefs = state.notifyPrefs;

    // Split once here rather than filtering twice in the list below.
    final byTime = prefs.byTime;
    final forHabits = byTime.where((r) => r.isForHabit).toList();
    final general = byTime.where((r) => !r.isForHabit).toList();

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
            NotificationContent.screenTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            k.geometry.screenPadding,
            4,
            k.geometry.screenPadding,
            28,
          ),
          // The switch, then what arrives: the one evening nudge first — it is
          // the notification most people want — then the reminders you set up
          // yourself, then the small extras. Each part says what it is in a
          // line and no more.
          children: [
            const _MasterCard(),
            if (prefs.enabled) ...[
              const _SectionLabel(NotificationContent.sectionDaily),
              const _EveningNudgeCard(),
              const _SectionLabel(NotificationContent.sectionReminders),
              _KindCard(
                icon: Icons.check_circle_outline,
                title: NotificationContent.kindHabitTitle,
                subtitle: NotificationContent.habitRemindersLine,
                value: prefs.habitRemindersEnabled,
                onChanged: state.setHabitRemindersEnabled,
                children: [
                  if (forHabits.isEmpty)
                    const _Quiet(NotificationContent.kindHabitEmpty)
                  else
                    for (final reminder in forHabits)
                      _ReminderCard(reminder: reminder),
                  // Habit reminders are set on a habit's own page, so the way
                  // to one is a way to the habits.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        homeTabRequests.value++;
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(NotificationContent.goToHabits),
                      style: TextButton.styleFrom(
                        foregroundColor: k.colors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ],
              ),
              // General reminders are the extra: off to begin with, and for
              // whoever goes looking. They sit with the quote, not with the
              // reminders every habit has.
              const _SectionLabel(NotificationContent.sectionMore),
              _KindCard(
                icon: Icons.notifications_none,
                title: NotificationContent.generalTitle,
                subtitle: NotificationContent.generalLine,
                value: prefs.generalEnabled,
                onChanged: state.setGeneralRemindersEnabled,
                children: [
                  for (final reminder in general)
                    _ReminderCard(reminder: reminder),
                  const SizedBox(height: 6),
                  const _AddButton(),
                ],
              ),
              const SizedBox(height: 10),
              const _QuoteCard(),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The master switch, and — when the two disagree — what the system thinks.
///
/// The preference and the permission are different questions, and they can
/// disagree in both directions. A switch that reads "on" while Android is
/// dropping every send is the worst version of this screen: nothing arrives
/// and nothing on the page admits it. So the system is asked directly, on
/// open and after every toggle, and its answer is shown when it contradicts
/// the switch.
class _MasterCard extends StatefulWidget {
  const _MasterCard();

  @override
  State<_MasterCard> createState() => _MasterCardState();
}

class _MasterCardState extends State<_MasterCard> {
  /// Null until the first answer comes back — no warning is shown while the
  /// question is still out, because a warning that flashes on every open is
  /// one people learn to ignore.
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final allowed = await context.read<AppState>().systemNotificationsAllowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _toggle(bool on) async {
    final state = context.read<AppState>();

    if (!on) {
      await state.disableNotifications();
      await _check();
      return;
    }

    final granted = await state.enableNotifications();
    await _check();
    if (!granted && mounted) {
      await showAppSnackBar(
        context,
        message: NotificationContent.permissionDenied,
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final prefs = state.notifyPrefs;
    final blocked = _allowed == false;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: prefs.enabled
                      ? k.colors.accentSoft
                      : k.colors.surfaceSoft,
                ),
                child: Icon(
                  prefs.enabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 21,
                  color: prefs.enabled ? k.colors.accent : k.colors.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NotificationContent.masterTitle,
                      style: k.text.cardTitle,
                    ),
                    // "All set" would contradict the blocked notice below.
                    if (!(prefs.enabled && blocked))
                      Text(
                        prefs.enabled
                            ? NotificationContent.masterOnLine
                            : NotificationContent.masterOffLine,
                        style: k.text.caption.copyWith(fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              Switch(
                value: prefs.enabled,
                activeThumbColor: Colors.white,
                activeTrackColor: k.colors.accent,
                onChanged: _toggle,
              ),
            ],
          ),

          // The disagreement, said plainly, with the one instruction that
          // fixes it. This is the state the app cannot fix for itself.
          if (blocked) ...[
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.block,
              text: NotificationContent.systemBlocked,
              tone: k.colors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

/// A line of small print with an icon, under the master switch.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: tone),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: k.text.caption.copyWith(fontSize: 11.5, color: tone),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.read<AppState>();
    final dimmed = !reminder.enabled;

    return InkWell(
      borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      onTap: () => ReminderEditorSheet.show(context, reminder: reminder),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 9, 0, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The time leads: this list reads as a day from top to
                      // bottom, and the hour is what distinguishes one row.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            reminder.time.format(),
                            style: k.text.captionStrong.copyWith(
                              fontSize: 15,
                              color: dimmed
                                  ? k.colors.textMuted
                                  : k.colors.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              reminder.scheduleLabel,
                              style: k.text.caption.copyWith(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (reminder.isForHabit)
                        _HabitChip(habitId: reminder.habitId!),
                      Text(
                        reminder.text,
                        style: k.text.captionStrong.copyWith(
                          color: dimmed ? k.colors.textMuted : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: reminder.enabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: k.colors.accent,
                  onChanged: (on) =>
                      state.saveReminder(reminder.copyWith(enabled: on)),
                ),
                DeleteReminderButton(reminder: reminder),
              ],
            ),
            if (kNotificationTestPanel) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final sent = await state.sendTestNotification(reminder);
                    if (!context.mounted) return;
                    await showAppSnackBar(
                      context,
                      message: sent
                          ? 'Sent — pull down the shade.'
                          : 'Add a habit first; there is nothing to say.',
                      duration: const Duration(milliseconds: 1600),
                    );
                  },
                  icon: const Icon(Icons.send_outlined, size: 15),
                  label: const Text('Send now'),
                  style: TextButton.styleFrom(
                    foregroundColor: k.colors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: k.text.caption.copyWith(fontSize: 11.5),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _PresetPicker.show(context),
        icon: const Icon(Icons.add, size: 19),
        label: Text(
          NotificationContent.addLabel,
          style: k.text.captionStrong.copyWith(color: k.colors.primary),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: k.colors.primary,
          side: BorderSide(color: k.colors.outline),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(k.geometry.chipRadius),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Ready-made wording, grouped by tone, so adding a reminder never starts at a
/// blank field. Everything here is editable after it is picked.
class _PresetPicker extends StatelessWidget {
  const _PresetPicker();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PresetPicker(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    NotificationContent.presetsTitle,
                    style: k.text.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ReminderEditorSheet.show(context);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(
                        NotificationContent.customLabel,
                        style: k.text.captionStrong.copyWith(
                          color: k.colors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: k.colors.primary,
                        side: BorderSide(color: k.colors.outline),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            k.geometry.chipRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final category in ReminderLibrary.categories) ...[
                    Row(
                      children: [
                        Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(width: 7),
                        Text(category.name, style: k.text.cardTitle),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            category.blurb,
                            style: k.text.caption.copyWith(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final preset in category.presets)
                      _PresetRow(preset: preset),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.preset});

  final ReminderPreset preset;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(k.geometry.innerRadius),
          onTap: () {
            Navigator.of(context).pop();
            ReminderEditorSheet.show(context, preset: preset);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            child: Text(preset.text, style: k.text.captionStrong),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A small heading between the groups of cards.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: k.text.captionStrong.copyWith(
          fontSize: 11,
          letterSpacing: 0.8,
          color: k.colors.textSecondary,
        ),
      ),
    );
  }
}

/// A row with an icon, a name, one line under it and a switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      children: [
        Icon(icon, size: 20, color: k.colors.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: k.text.cardTitle),
              Text(subtitle, style: k.text.caption.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: k.colors.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The one notification the app writes itself, for two reasons.
///
/// The daily catch-up and the 21-day challenge share it: both are "today is
/// not done yet", so both arrive as the same single send at the same time.
/// While the challenge runs it does the talking. Laid out as one card so the
/// sharing is visible rather than explained.
class _EveningNudgeCard extends StatelessWidget {
  const _EveningNudgeCard();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final prefs = state.notifyPrefs;

    return KCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
      child: Column(
        children: [
          _SwitchRow(
            icon: Icons.local_fire_department_outlined,
            title: NotificationContent.catchUpTitleLabel,
            subtitle: NotificationContent.catchUpLine,
            value: prefs.catchUpEnabled,
            onChanged: state.setCatchUpEnabled,
          ),
          Divider(height: 14, color: k.colors.outline),
          _SwitchRow(
            icon: Icons.psychology_outlined,
            title: NotificationContent.challengeToggleTitle,
            subtitle: state.challengeLive
                ? NotificationContent.challengeToggleLine
                : NotificationContent.challengeNotStarted,
            value: prefs.challengeEnabled,
            onChanged: state.setChallengeNudgeEnabled,
          ),
          if (prefs.nudgeEnabled) ...[
            Divider(height: 14, color: k.colors.outline),
            const _CatchUpTime(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: k.colors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  NotificationContent.oneADay,
                  style: k.text.caption.copyWith(
                    fontSize: 11.5,
                    color: k.colors.textMuted,
                  ),
                ),
              ],
            ),
            if (kNotificationTestPanel)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final sent = await state.sendTestNudge();
                    if (!context.mounted) return;
                    await showAppSnackBar(
                      context,
                      message: sent
                          ? 'Sent — pull down the shade.'
                          : 'Nothing to send: today is done, or empty.',
                      duration: const Duration(milliseconds: 1600),
                    );
                  },
                  icon: const Icon(Icons.send_outlined, size: 15),
                  label: const Text('Send now'),
                  style: TextButton.styleFrom(
                    foregroundColor: k.colors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: k.text.caption.copyWith(fontSize: 11.5),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// When the evening nudge arrives.
class _CatchUpTime extends StatelessWidget {
  const _CatchUpTime();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final prefs = state.notifyPrefs;

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: prefs.catchUpTime.hour,
          minute: prefs.catchUpTime.minute,
        ),
        initialEntryMode: TimePickerEntryMode.dial,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      );
      if (picked == null) return;
      await state.setCatchUpTime(TimeOfDayValue(picked.hour, picked.minute));
    }

    return Row(
      children: [
        Icon(Icons.schedule, size: 20, color: k.colors.primary),
        const SizedBox(width: 11),
        Expanded(
          child: Text(NotificationContent.nudgeTime, style: k.text.cardTitle),
        ),
        Material(
          color: k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(k.geometry.pillRadius),
          child: InkWell(
            onTap: pickTime,
            borderRadius: BorderRadius.circular(k.geometry.pillRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prefs.catchUpTime.format(),
                    style: k.text.captionStrong.copyWith(
                      fontSize: 13.5,
                      color: k.colors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 16, color: k.colors.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// The day's quote under every reminder, one switch for all of them.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return KCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: _SwitchRow(
        icon: Icons.format_quote,
        title: NotificationContent.withQuoteTitle,
        subtitle: NotificationContent.withQuoteBlurb,
        value: state.notifyPrefs.appendQuote,
        onChanged: state.setAppendQuote,
      ),
    );
  }
}

/// One kind of notification: its name, its switch, and — while it is on —
/// what belongs to it.
class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;

  /// One short line under the title, for a kind whose name does not say it.
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: k.colors.primary),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: k.text.cardTitle),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: k.text.caption.copyWith(fontSize: 11.5),
                      ),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeThumbColor: Colors.white,
                activeTrackColor: k.colors.accent,
                onChanged: onChanged,
              ),
            ],
          ),
          if (value) ...[
            Divider(height: 10, color: k.colors.outline),
            ...children,
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// A single muted line, for a kind with nothing in it yet.
class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: k.text.caption),
    );
  }
}

class _HabitChip extends StatelessWidget {
  const _HabitChip({required this.habitId});

  final String habitId;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final Habit? habit = context
        .watch<AppState>()
        .allHabits
        .where((h) => h.id == habitId)
        .firstOrNull;
    if (habit == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: k.colors.primarySoft,
          borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        ),
        child: Text(
          habit.name,
          style: k.text.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: k.colors.primary,
          ),
        ),
      ),
    );
  }
}
