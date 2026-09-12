import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_snackbar.dart';

/// Makes a change to a habit on [day], asking first when that day is part
/// of the 21-day challenge and already over.
///
/// Those days are locked: going back to one would rewrite the run. So it
/// says what will happen, and only on a yes makes the change and restarts
/// the challenge from day 1, today. Every other day — today, days before the
/// challenge, any day with no challenge running — just changes.
Future<void> editChallengeDay(
  BuildContext context,
  DateTime day,
  Future<void> Function() edit,
) async {
  final state = context.read<AppState>();
  if (!state.challengeLocks(day)) {
    await edit();
    return;
  }

  final k = context.k;
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: k.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
      ),
      icon: Icon(Icons.lock_clock_outlined, color: k.colors.primary, size: 30),
      title: Text(
        AppContent.challengeLockTitle,
        style: k.text.cardTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        AppContent.challengeLockBody,
        style: k.text.body,
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            AppContent.challengeLockKeep,
            style: k.text.captionStrong.copyWith(color: k.colors.primary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            AppContent.challengeLockGo,
            style: k.text.captionStrong.copyWith(color: k.colors.danger),
          ),
        ),
      ],
    ),
  );
  if (go != true) return;

  await edit();
  await state.restartChallenge();
  if (context.mounted) {
    await showAppSnackBar(context, message: AppContent.challengeRestarted);
  }
}
