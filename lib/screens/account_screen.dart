import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_background.dart';
import '../widgets/k_card.dart';
import '../widgets/profile_photo.dart';
import '../widgets/settings_group.dart';
import 'profile_editor_sheet.dart';

/// Who you are to the app, and what it is holding on your behalf.
///
/// There is no account here in the usual sense — no sign-in, no server, no
/// password to reset. Rather than invent one, the screen covers what an
/// account screen is actually for: your details, what is stored, how much of
/// it there is, a copy of it, and the way out.
///
/// Laid out as grouped rows rather than a stack of separate cards. Eight
/// floating cards give eight unrelated things the same weight; four groups say
/// which of them belong together before a word is read.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccountScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
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
            AppContent.accountTitle,
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
          children: [
            const _Identity(),
            const SizedBox(height: 18),

            // Last, on its own, and the only red on the screen.
            SettingsGroup(
              title: AppContent.groupDanger,
              children: [
                SettingsRow(
                  icon: Icons.person_off_outlined,
                  label: AppContent.accountDeleteTitle,
                  subtitle: AppContent.accountDeleteBody,
                  destructive: true,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final k = context.k;
    final state = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(AppContent.accountDeleteTitle, style: k.text.cardTitle),
        content: Text(AppContent.accountDeleteConfirm, style: k.text.body),
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
              AppContent.accountDeleteTitle,
              style: k.text.captionStrong.copyWith(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.resetAll();
    if (!context.mounted) return;
    // Back to Profile: staying here would leave a page of zeroes as the last
    // thing that happened.
    Navigator.of(context).pop();
    await showAppSnackBar(context, message: AppContent.accountDeleted);
  }
}

// ---------------------------------------------------------------------------

/// The block at the top: a face, a name, and how long this has been going on.
class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final profile = state.profile;

    return KCard(
      onTap: () => ProfileEditorSheet.show(context),
      child: Row(
        children: [
          // The same face as the header, not a second rendering of it: an
          // initial here and a photograph there would read as two people.
          const ProfilePhoto(size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    profile.name,
                    maxLines: 1,
                    style: k.text.cardTitle.copyWith(fontSize: 17),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.personalQuote,
                  style: k.text.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.edit_outlined, size: 18, color: k.colors.primary),
        ],
      ),
    );
  }
}
