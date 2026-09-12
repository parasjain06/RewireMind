import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/journal_content.dart';
import '../models/journal_entry.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/journal_widgets.dart';
import '../widgets/k_card.dart';

/// Writing an entry, or reading and changing one.
///
/// Never a blank page: it opens on the prompts that suit the hour — the
/// morning's intention, the evening's reflection — with the mood first,
/// because a mood alone is already worth saving. The day's habits come with
/// it automatically, so an entry is never just words floating free of what
/// actually happened.
class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({super.key, this.entry, this.day, this.template});

  /// The entry to open, or null for a new one.
  final JournalEntry? entry;

  /// For a new entry: the day it is about. Today when null.
  final DateTime? day;

  /// For a new entry: which prompts to start on. Suggested by the hour when
  /// null.
  final String? template;

  static Future<void> open(
    BuildContext context, {
    JournalEntry? entry,
    DateTime? day,
    String? template,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            JournalEditorScreen(entry: entry, day: day, template: template),
      ),
    );
  }

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late JournalEntry _entry;
  late String _template;
  late int? _mood;
  late Set<String> _feelings;
  final Map<String, TextEditingController> _fields = {};
  final Random _shuffle = Random();
  late int _prompt;
  bool _dirty = false;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _entry =
        widget.entry ??
        state.draftJournalEntry(
          widget.template ?? JournalContent.suggestedFor(DateTime.now()).key,
          day: widget.day,
        );
    // A check-in opened for words becomes a free write about the same day.
    _template = _entry.template == 'checkin' ? 'free' : _entry.template;
    _mood = _entry.mood;
    _feelings = {..._entry.feelings};
    for (final e in _entry.answers.entries) {
      _controller(e.key).text = e.value;
    }
    // A check-in's one line carries over into the free write.
    final note = _entry.answers['note'];
    if (note != null && (_entry.answers['text'] ?? '').isEmpty) {
      _controller('text').text = note;
    }
    _prompt = _shuffle.nextInt(JournalContent.freePrompts.length);
  }

  TextEditingController _controller(String key) => _fields.putIfAbsent(
    key,
    () => TextEditingController()..addListener(() => _dirty = true),
  );

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  JournalTemplate get _current => JournalContent.template(_template);

  /// What would be saved: the answers to this template's prompts only.
  Map<String, String> get _answers => {
    for (final (key, _) in _current.prompts)
      if ((_fields[key]?.text.trim() ?? '').isNotEmpty)
        key: _fields[key]!.text.trim(),
  };

  bool get _empty => _mood == null && _feelings.isEmpty && _answers.isEmpty;

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (_empty) {
      // Nothing to keep: a new one simply is not made, and an old one
      // emptied out is the same as deleting it.
      if (!_isNew) await state.deleteJournalEntry(_entry.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await state.saveJournalEntry(
      _entry.copyWith(
        template: _template,
        mood: _mood,
        clearMood: _mood == null,
        feelings: _feelings.toList(),
        answers: _answers,
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    await showAppSnackBar(context, message: JournalContent.homeSaved);
  }

  Future<void> _delete() async {
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final gone = await state.deleteJournalEntry(_entry.id);
    navigator.pop();
    if (gone == null || !mounted) return;
    await showAppSnackBar(
      context,
      message: JournalContent.editorDeleted,
      actionLabel: 'Undo',
      onAction: () => state.saveJournalEntry(gone),
    );
  }

  /// Leaving with words unsaved asks first; leaving an untouched page does
  /// not.
  Future<bool> _mayLeave() async {
    if (!_dirty || _empty) return true;
    final k = context.k;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        title: Text(JournalContent.editorDiscardTitle, style: k.text.cardTitle),
        content: Text(JournalContent.editorDiscardBody, style: k.text.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(JournalContent.editorKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              JournalContent.editorDiscard,
              style: TextStyle(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _pickDay() async {
    final state = context.read<AppState>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _entry.day,
      firstDate: DateTime(2020),
      lastDate: state.today,
    );
    if (picked == null) return;
    setState(() {
      _entry = _entry.copyWith(
        day: DateTime(picked.year, picked.month, picked.day),
      );
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _mayLeave()) navigator.pop();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: k.colors.primary),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickDay,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('EEE d MMM').format(_entry.day),
                      style: k.text.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: k.colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!_isNew)
                IconButton(
                  tooltip: JournalContent.editorDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: k.colors.textSecondary,
                  ),
                  onPressed: _delete,
                ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              4,
              k.geometry.screenPadding,
              24,
            ),
            children: [
              _TemplateChips(
                selected: _template,
                onSelect: (key) => setState(() {
                  _template = key;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 14),
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(JournalContent.editorMood, style: k.text.cardTitle),
                    const SizedBox(height: 12),
                    MoodPicker(
                      selected: _mood,
                      onPick: (value) => setState(() {
                        _mood = _mood == value ? null : value;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      JournalContent.editorFeelings,
                      style: k.text.captionStrong.copyWith(
                        color: k.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (key, label) in JournalContent.feelings)
                          _FeelingChip(
                            label: label,
                            on: _feelings.contains(key),
                            onTap: () => setState(() {
                              _feelings.contains(key)
                                  ? _feelings.remove(key)
                                  : _feelings.add(key);
                              _dirty = true;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, (key, question))
                        in _current.prompts.indexed) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _Prompt(
                        question: _template == 'free'
                            ? JournalContent.freePrompts[_prompt]
                            : question,
                        controller: _controller(key),
                        big: _template == 'free',
                      ),
                    ],
                    if (_template == 'free')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _prompt =
                                (_prompt + 1) %
                                JournalContent.freePrompts.length,
                          ),
                          icon: const Icon(Icons.shuffle_rounded, size: 17),
                          label: Text(JournalContent.editorShuffle),
                          style: TextButton.styleFrom(
                            foregroundColor: k.colors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DayContext(day: _entry.day),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              8,
              k.geometry.screenPadding,
              12,
            ),
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: k.colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(k.geometry.innerRadius),
                  ),
                  textStyle: k.text.bodyStrong,
                ),
                child: Text(JournalContent.editorSave),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The four kinds of entry, two by two.
///
/// They used to be a row that scrolled sideways, which showed two and a half
/// of them and gave no sign there were more — a picker you have to discover
/// is half a picker. Four tiles fit across two lines at any phone width.
class _TemplateChips extends StatelessWidget {
  const _TemplateChips({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final templates = JournalContent.templates;
    return Column(
      children: [
        for (var row = 0; row < (templates.length + 1) ~/ 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: row * 2 + col < templates.length
                      ? _TemplateTile(
                          template: templates[row * 2 + col],
                          selected: templates[row * 2 + col].key == selected,
                          onTap: () => onSelect(templates[row * 2 + col].key),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One kind of entry: what it is called, and what it asks for.
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final JournalTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final radius = BorderRadius.circular(k.geometry.innerRadius);

    return Material(
      color: selected ? k.colors.primary : k.colors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? k.colors.primary : k.colors.outline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                template.icon,
                size: 18,
                color: selected ? Colors.white : k.colors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: k.text.captionStrong.copyWith(
                        fontSize: 12,
                        color: selected ? Colors.white : k.colors.textPrimary,
                      ),
                    ),
                    Text(
                      template.blurb,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: k.text.caption.copyWith(
                        fontSize: 10,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : k.colors.textMuted,
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

class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? k.colors.accentSoft : k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? k.colors.accent : Colors.transparent),
        ),
        child: Text(
          label,
          style: k.text.caption.copyWith(
            fontSize: 12.5,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            color: on ? k.colors.primary : k.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// One question and its answer: soft, borderless, and grows as you write.
class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.question,
    required this.controller,
    this.big = false,
  });

  final String question;
  final TextEditingController controller;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: k.text.cardTitle.copyWith(fontSize: 14.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: big ? 6 : 2,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: k.text.body.copyWith(fontSize: 15, height: 1.45),
          decoration: InputDecoration(
            filled: true,
            fillColor: k.colors.surfaceSoft,
            hintText: big ? null : 'Write a line…',
            hintStyle: k.text.body.copyWith(color: k.colors.textMuted),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(k.geometry.innerRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// The day's habits, attached to the entry without being asked: what you
/// did sits next to how it felt.
class _DayContext extends StatelessWidget {
  const _DayContext({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final scheduled = state.scheduledOn(day);
    final done = [
      for (final h in scheduled)
        if (state.isComplete(h, day)) h,
    ];
    final streak = day == state.today ? state.perfectStreak : 0;

    return KCard(
      soft: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 17, color: k.colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  JournalContent.context(done.length, scheduled.length, streak),
                  style: k.text.captionStrong,
                ),
              ),
            ],
          ),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in done)
                  Tooltip(
                    message: h.name,
                    child: IconChip(
                      iconKey: h.iconKey,
                      icon: AppIcons.forKey(h.iconKey),
                      size: 30,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
