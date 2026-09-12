import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/k_card.dart';
import 'roadmap_screen.dart';

/// The terms of the 21-day challenge, before anybody is on day one of it.
///
/// This screen exists because of one rule: a missed day puts the run back to
/// nothing. That is a real cost, and finding it out on the day it happens
/// would feel like the app moving the goalposts. Told up front it is the point
/// of the thing — twenty-one *consecutive* days is the claim, and a tally with
/// gaps in it would be a different, easier claim.
class ChallengeRulesScreen extends StatefulWidget {
  const ChallengeRulesScreen({super.key, this.startsChallenge = true});

  /// True on the way in to the path for the first time, when the button
  /// carries on to it. False when the rules are being re-read from the path
  /// itself, where a "start" button would be nonsense — you are already on it.
  final bool startsChallenge;

  static Future<void> open(
    BuildContext context, {
    bool startsChallenge = true,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeRulesScreen(startsChallenge: startsChallenge),
      ),
    );
  }

  @override
  State<ChallengeRulesScreen> createState() => _ChallengeRulesScreenState();
}

class _ChallengeRulesScreenState extends State<ChallengeRulesScreen> {
  /// Ticked before the button will do anything.
  ///
  /// The one rule that matters — miss a day and it starts again — is the one
  /// people are surprised by three weeks in, and "I never agreed to that" is
  /// a fair complaint about a screen you can walk straight past. One tick is
  /// the difference between having been shown the rules and having read them.
  bool _agreed = false;

  Future<void> _begin(BuildContext context) async {
    final navigator = Navigator.of(context);
    final state = context.read<AppState>();
    await state.markChallengeRulesSeen();
    // Pressing the button is the moment the challenge starts, and today is
    // day one. Nothing before this counted towards it.
    if (!state.challengeLive) await state.startChallenge();
    if (!context.mounted) return;

    // Replaced rather than stacked: going back from the path should reach the
    // page you came from, not the rules you have just agreed to.
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const RoadmapScreen()),
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
            AppContent.rulesTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  k.geometry.screenPadding,
                  4,
                  k.geometry.screenPadding,
                  20,
                ),
                children: [
                  const _Headline(),
                  const SizedBox(height: 12),
                  // Second, not last. It was at the foot of the page under
                  // five cards, which on a phone put the one rule that
                  // changes how you use the app below the fold — far enough
                  // down that the list had not even built it. The rule that
                  // costs something goes where it will be read.
                  const _HardRule(),
                  const SizedBox(height: 16),
                  for (var i = 0; i < AppContent.rules.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Rule(number: i + 1, rule: AppContent.rules[i]),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                k.geometry.screenPadding,
                4,
                k.geometry.screenPadding,
                14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.startsChallenge) ...[
                    _Agreement(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: !widget.startsChallenge
                          ? () => Navigator.of(context).pop()
                          : (_agreed ? () => _begin(context) : null),
                      style: FilledButton.styleFrom(
                        backgroundColor: k.colors.accent,
                        disabledBackgroundColor: k.colors.accentTrack,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            k.geometry.pillRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        widget.startsChallenge
                            ? AppContent.rulesBegin
                            : AppContent.rulesBack,
                        style: k.text.captionStrong.copyWith(
                          fontSize: 14,
                          color: Colors.white,
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
    );
  }
}

// ---------------------------------------------------------------------------

/// The tick that turns the button on.
class _Agreement extends StatelessWidget {
  const _Agreement({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      child: InkWell(
        // The whole row, not just the box: a 20px target for the one thing
        // standing between somebody and the button is a bad joke.
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: k.colors.accent,
                  side: BorderSide(color: k.colors.outline, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  AppContent.rulesAgree,
                  style: k.text.body.copyWith(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      soft: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧠', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppContent.rulesHeadline, style: k.text.cardTitle),
                const SizedBox(height: 7),
                for (final line in AppContent.rulesPromise)
                  _Bullet(text: line, tint: k.colors.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.number, required this.rule});

  final int number;
  final String rule;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered because these are in order of when they apply, not
          // because a list needs decorating.
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: k.colors.accentSoft,
            ),
            child: Text(
              '$number',
              style: k.text.captionStrong.copyWith(
                fontSize: 12,
                color: k.colors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(rule, style: k.text.body.copyWith(height: 1.4))),
        ],
      ),
    );
  }
}

/// The one that costs something, given its own weight on the page.
class _HardRule extends StatelessWidget {
  const _HardRule();

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      padding: EdgeInsets.all(k.geometry.cardPadding),
      decoration: BoxDecoration(
        color: k.colors.dangerSoft,
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        border: Border.all(color: k.colors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restart_alt, size: 22, color: k.colors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppContent.rulesHardTitle,
                  style: k.text.cardTitle.copyWith(color: k.colors.danger),
                ),
                const SizedBox(height: 7),
                for (final line in AppContent.rulesHard)
                  _Bullet(text: line, tint: k.colors.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One short line with a dot against it.
///
/// Shared by both cards on this screen, so a rule and a consequence are set
/// the same way and only their colour differs.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.tint});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: k.text.caption.copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }
}
