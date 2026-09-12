import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/k_card.dart';
import '../models/premium.dart';

/// Whether Profile shows the Test app row at all.
///
/// Its tools are for looking at the app, not for using it: a made-up
/// history, a challenge moved to day two, and a clean slate. Built in with
/// `--dart-define=DEV_TOOLS=true` and left out of store builds.
const bool kTestAppRow = bool.fromEnvironment('DEV_TOOLS');

/// Tools for trying the app out, kept apart from the settings people use.
class TestAppScreen extends StatelessWidget {
  const TestAppScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TestAppScreen()));
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
            AppContent.testAppTitle,
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
          children: const [
            _DemoCard(),
            SizedBox(height: 10),
            _RehearseCard(),
            SizedBox(height: 10),
            _PreviewSendsCard(),
            SizedBox(height: 10),
            _PremiumCard(),
            SizedBox(height: 10),
            _StartOverCard(),
            SizedBox(height: 10),
            _FreshInstallCard(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Loads the bundled demo history.
///
/// Goes through the very same [AppState.inspectBackup] and
/// [AppState.restoreBackup] a real file does, so this row cannot get a
/// dataset into the app that a restore would have refused.
/// Stands the challenge on day two, so the walk can be watched now.
///
/// The animation only fires on a day boundary, which makes it the one thing in
/// the app you cannot look at on demand. This sets the state somebody is
/// actually in on the morning after keeping day one — the walk that follows is
/// the real one, on the real trigger.
class _RehearseCard extends StatelessWidget {
  const _RehearseCard();

  Future<void> _run(BuildContext context) async {
    final state = context.read<AppState>();

    // A day with nothing logged has no run behind it, and the walk will
    // rightly decline to celebrate it. Say so here rather than let somebody
    // tap this and conclude the feature is broken.
    if (!state.isPerfectDay(state.today)) {
      await showAppSnackBar(
        context,
        message: AppContent.dataRehearseNeedsDay,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    await state.rehearseChallengeDay();
    if (!context.mounted) return;
    await showAppSnackBar(
      context,
      message: AppContent.dataRehearseDone,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.replay_outlined,
    title: AppContent.dataRehearseTitle,
    body: AppContent.dataRehearseBody,
    onTap: () => _run(context),
  );
}

/// Premium on and off, so both tiers can be looked at.
class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<AppState>().isPremium;
    return _Row(
      icon: premium ? Icons.lock_open_rounded : Icons.workspace_premium_rounded,
      title: premium ? AppContent.testFreeTitle : AppContent.testPremiumTitle,
      body: premium ? AppContent.testFreeBody : AppContent.testPremiumBody,
      onTap: () async {
        final state = context.read<AppState>();
        if (premium) {
          await state.clearPremium();
        } else {
          await state.unlockPremium(PremiumPlan.lifetime, source: 'dev');
        }
        if (!context.mounted) return;
        await showAppSnackBar(
          context,
          message: premium
              ? AppContent.testFreeDone
              : AppContent.testPremiumDone,
        );
      },
    );
  }
}

/// Posts the evening send in each of its shapes, so what the shade will say
/// can be read in the shade.
class _PreviewSendsCard extends StatelessWidget {
  const _PreviewSendsCard();

  Future<void> _run(BuildContext context) async {
    final state = context.read<AppState>();
    final sent = await state.previewEveningSends();
    if (!context.mounted) return;
    await showAppSnackBar(
      context,
      message: sent == 0
          ? AppContent.previewSendsNeedsHabits
          : AppContent.previewSendsDone(sent),
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.notifications_active_outlined,
    title: AppContent.previewSendsTitle,
    body: AppContent.previewSendsBody,
    onTap: () => _run(context),
  );
}

class _DemoCard extends StatelessWidget {
  const _DemoCard();

  Future<void> _run(BuildContext context) async {
    final state = context.read<AppState>();
    final raw = await DefaultAssetBundle.of(context)
        .loadString('assets/demo/demo_backup.json');

    // Ending yesterday, so the run it was built with is still a run today.
    final backup = AppState.inspectBackup(
      AppState.freshenDemo(raw, state.today.subtract(const Duration(days: 1))),
    );
    if (backup == null) {
      if (context.mounted) {
        await showAppSnackBar(
          context,
          message: AppContent.dataImportUnreadable,
        );
      }
      return;
    }

    await state.restoreBackup(backup);
    await state.seedDemoJournal();
    if (!context.mounted) return;
    await showAppSnackBar(
      context,
      message: AppContent.dataDemoDone(backup.habits, backup.checkIns),
    );
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.auto_awesome_outlined,
    title: AppContent.dataDemoTitle,
    body: AppContent.dataDemoBody,
    onTap: () => _run(context),
  );
}

// ---------------------------------------------------------------------------

/// Clears every habit and its history, keeps the person. Asked first,
/// because it cannot be undone.
class _StartOverCard extends StatelessWidget {
  const _StartOverCard();

  Future<void> _confirm(BuildContext context) async {
    final k = context.k;
    final state = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(AppContent.resetTitle, style: k.text.cardTitle),
        content: Text(AppContent.resetBody, style: k.text.body),
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
              AppContent.resetConfirm,
              style: k.text.captionStrong.copyWith(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await state.startOver();
    if (context.mounted) {
      await showAppSnackBar(context, message: AppContent.resetDone);
    }
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.restart_alt,
    title: AppContent.resetRowTitle,
    body: AppContent.resetRowBody,
    onTap: () => _confirm(context),
  );
}

/// Everything gone, back to the sign-in screen: the first launch, again.
class _FreshInstallCard extends StatelessWidget {
  const _FreshInstallCard();

  Future<void> _confirm(BuildContext context) async {
    final k = context.k;
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(AppContent.freshConfirmTitle, style: k.text.cardTitle),
        content: Text(AppContent.freshConfirmBody, style: k.text.body),
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
              AppContent.freshConfirm,
              style: k.text.captionStrong.copyWith(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Off every screen first: with the name gone the app's root becomes the
    // sign-in screen, and anything left pushed above it would sit on top.
    navigator.popUntil((r) => r.isFirst);
    await state.freshInstall();
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.phonelink_erase_outlined,
    title: AppContent.freshTitle,
    body: AppContent.freshBody,
    onTap: () => _confirm(context),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: k.colors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: k.text.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(body, style: k.text.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
