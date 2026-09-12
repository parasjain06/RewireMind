import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_photo.dart';

/// Edits everything on the Profile header in one place: name, bio and the
/// quote. Profile used to carry two separate "Edit" affordances — one on the
/// header, one on the quote bar — which read as two different features.
class ProfileEditorSheet extends StatefulWidget {
  const ProfileEditorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileEditorSheet(),
    );
  }

  @override
  State<ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<ProfileEditorSheet> {
  late final UserProfile _profile = context.read<AppState>().profile;
  late final TextEditingController _name = TextEditingController(
    text: _profile.name,
  );
  late final TextEditingController _quote = TextEditingController(
    text: _profile.personalQuote,
  );

  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _quote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppContent.profileNameRequired);
      return;
    }

    await context.read<AppState>().updateProfile(
      _profile.copyWith(
        name: name,
        personalQuote: _quote.text.trim().isEmpty
            ? _profile.personalQuote
            : _quote.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppContent.profileEditTitle,
                      style: k.text.sectionTitle,
                    ),
                    const SizedBox(height: 16),
                    // The picture belongs with the name and the quote. Editing
                    // "your profile" and finding the photograph is not one of
                    // the things you can edit is the sort of gap people go
                    // hunting through settings for.
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ProfilePhoto(
                            size: 76,
                            onTap: () => chooseProfilePhoto(context),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppContent.profilePhotoHint,
                            style: k.text.caption.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Label(AppContent.profileNameLabel),
                    _Field(controller: _name, onChanged: _clearError),
                    const SizedBox(height: 16),
                    _Label(AppContent.profileQuoteLabel),
                    _Field(
                      controller: _quote,
                      hint: AppContent.profileQuoteHint,
                      maxLines: 2,
                    ),
                    // Offered under the field rather than instead of it. Most
                    // people do not have a line of their own ready, and the
                    // ones who do should not have to scroll a list to get past
                    // the offer.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _pickQuote,
                        icon: Icon(
                          Icons.format_quote,
                          size: 17,
                          color: k.colors.accent,
                        ),
                        label: Text(
                          AppContent.profileQuotePick,
                          style: k.text.captionStrong.copyWith(
                            fontSize: 12.5,
                            color: k.colors.accent,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 15,
                            color: k.colors.danger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _error!,
                            style: k.text.caption.copyWith(
                              color: k.colors.danger,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Material(
                      color: k.colors.primary,
                      borderRadius: BorderRadius.circular(
                        k.geometry.pillRadius,
                      ),
                      child: InkWell(
                        onTap: _save,
                        borderRadius: BorderRadius.circular(
                          k.geometry.pillRadius,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: Text(
                              AppContent.profileSaveButton,
                              style: k.text.cardTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          AppContent.editorCancel,
                          style: k.text.bodyStrong.copyWith(
                            color: k.colors.textSecondary,
                          ),
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

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  /// The library, and whatever is chosen lands in the field rather than
  /// straight on the profile — so it can still be edited before saving, and
  /// so Cancel means cancel.
  Future<void> _pickQuote() async {
    // Whatever is typed comes off the keyboard first: the sheet is tall, and
    // opening it under a keyboard leaves half of it unreachable.
    FocusScope.of(context).unfocus();

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuoteLibrarySheet(selected: _quote.text.trim()),
    );
    if (chosen == null || !mounted) return;
    setState(() => _quote.text = chosen);
  }
}

/// Every quote the app knows, to pick one from.
class _QuoteLibrarySheet extends StatelessWidget {
  const _QuoteLibrarySheet({required this.selected});

  /// What the field says now, so the list can show which one that is.
  final String selected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final quotes = AppContent.profileQuoteLibrary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppContent.profileQuoteSheet,
                  style: k.text.sectionTitle,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                itemCount: quotes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (context, i) => _QuoteOption(
                  quote: quotes[i],
                  chosen: quotes[i] == selected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteOption extends StatelessWidget {
  const _QuoteOption({required this.quote, required this.chosen});

  final String quote;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Material(
      color: chosen ? k.colors.accentSoft : k.colors.surfaceSoft,
      borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(quote),
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  quote,
                  style: k.text.bodyStrong.copyWith(
                    fontSize: 13.5,
                    color: chosen ? k.colors.accent : null,
                  ),
                ),
              ),
              if (chosen)
                Icon(Icons.check_circle, size: 18, color: k.colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
