import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../content/app_content.dart';
import '../content/app_links.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/link_row.dart';
import '../widgets/settings_group.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// How the app works, what people keep asking, and how to tell us it doesn't.
///
/// It used to be two rows: watch the tour, send an email. That is a contact
/// form with a link on it, not a help screen — everything somebody might
/// actually want to know was somewhere else or nowhere. The questions in the
/// middle are the ones the app's own behaviour provokes, answered honestly
/// rather than reassuringly.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HelpScreen()));
  }

  /// Opens a mail draft with the build already in it.
  ///
  /// Carried into the message so a report arrives with the version it came
  /// from, rather than a follow-up question asking for it.
  Future<void> _mail(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final version = '${info.version} (${info.buildNumber})';
    await openLink(
      context,
      url: AppLinks.problem(version),
      failure: '${AppContent.helpNoMail}${AppLinks.feedbackEmail}',
    );
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
            AppContent.helpTitle,
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
            SettingsGroup(
              title: AppContent.groupStart,
              children: [
                // Neither of these leaves the app, so neither gets the
                // outward arrow — that arrow is a promise about losing your
                // place, and breaking it is worse than not making it.
                SettingsRow(
                  icon: Icons.school_outlined,
                  label: AppContent.helpTutorial,
                  subtitle: AppContent.helpTutorialBody,
                  onTap: () => OnboardingScreen.open(context),
                ),
                SettingsRow(
                  icon: Icons.explore_outlined,
                  label: AppContent.helpTour,
                  subtitle: AppContent.helpTourBody,
                  // Back to Home, where the tour points at the real thing.
                  onTap: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    homeTourRequests.value++;
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            SettingsGroup(
              title: AppContent.groupQuestions,
              children: [
                for (final (question, answer) in AppContent.helpFaq)
                  SettingsQuestion(question: question, answer: answer),
              ],
            ),
            const SizedBox(height: 18),

            SettingsGroup(
              title: AppContent.groupReach,
              children: [
                // Feedback has its own row on Profile now, so only problem
                // reports are sent from here.
                SettingsRow(
                  icon: Icons.bug_report_outlined,
                  label: AppContent.helpProblem,
                  subtitle: AppContent.helpProblemBody,
                  external: true,
                  onTap: () => _mail(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
