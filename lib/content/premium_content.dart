import 'package:flutter/material.dart';

import '../models/premium.dart';

/// One thing the paid tier holds.
@immutable
class PremiumPerk {
  const PremiumPerk(this.icon, this.title, this.line);

  final IconData icon;
  final String title;

  /// One short line. This page sells by showing the list, not by reading it
  /// out.
  final String line;
}

/// ============================================================================
/// THE PREMIUM PAGE'S WORDS
/// ============================================================================
class PremiumContent {
  const PremiumContent._();

  static const String title = 'Premium subscription';
  static const String eyebrow = 'REWIREMIND PREMIUM';
  static const String heroLine = 'Everything, unlocked.';
  static const String heroSub =
      'The challenge, the journal, every widget and as many habits as you '
      'want to build.';

  /// The row in Profile, and the chip on a locked thing.
  static const String menuTitle = 'Premium subscription';
  static const String menuLine = 'Unlock the challenge, journal and widgets';
  static const String menuLineActive = 'Thank you — everything is unlocked';
  static const String badge = 'Premium';

  /// Five lines, each the length of a chip: the page has one screen and the
  /// list is meant to be taken in, not read.
  static const List<PremiumPerk> perks = [
    PremiumPerk(
      Icons.bolt_rounded,
      'The 21-day challenge',
      'The path, the streak and the rules that hold you to it',
    ),
    PremiumPerk(
      Icons.auto_stories_outlined,
      'Journal',
      'A mood a day, words when you want them, and what lifts you',
    ),
    PremiumPerk(
      Icons.widgets_outlined,
      'Every home screen widget',
      "Today's checklist, the week, and the whole month",
    ),
    PremiumPerk(
      Icons.all_inclusive_rounded,
      'Unlimited habits',
      'Free keeps $kFreeHabitLimit, between building and cutting back',
    ),
    PremiumPerk(
      Icons.file_upload_outlined,
      'Import your data',
      'Put a backup back, on this phone or the next one',
    ),
  ];

  static const String includedTitle = "What's included";

  // -- the plans -------------------------------------------------------------

  static String planName(PremiumPlan plan) => switch (plan) {
    PremiumPlan.monthly => 'Monthly',
    PremiumPlan.annual => 'Annual',
    PremiumPlan.lifetime => 'Lifetime',
  };

  static String planPer(PremiumPlan plan) => switch (plan) {
    PremiumPlan.monthly => 'per month',
    PremiumPlan.annual => 'per year',
    PremiumPlan.lifetime => 'one payment',
  };

  static String planNote(PremiumPlan plan, PremiumPrices prices) =>
      switch (plan) {
        PremiumPlan.monthly => 'Cancel any time',
        PremiumPlan.annual =>
          prices.annualSaving == null
              ? 'Billed once a year'
              : 'Save ${prices.annualSaving}%',
        PremiumPlan.lifetime => 'Yours, for good',
      };

  static const String bestValue = 'Best value';

  static String cta(PremiumPlan plan) =>
      plan == PremiumPlan.lifetime ? 'Unlock for good' : 'Subscribe';

  static const String offerTitle = 'Launch offer ends in';

  /// The countdown, to the second — so it is plainly running rather than a
  /// number somebody painted on.
  static String offerClock(Duration left) {
    String two(int n) => n.toString().padLeft(2, '0');
    final days = left.inDays;
    final clock =
        '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}'
        ':${two(left.inSeconds % 60)}';
    return days > 0 ? '${days}d $clock' : clock;
  }

  /// Required on the page by both stores: that it renews, and how to stop it.
  static const String renewalTerms =
      'Subscriptions renew automatically until cancelled. Manage or cancel '
      'in your store account, any time. Lifetime is a single payment.';
  static const String terms = 'Terms';
  static const String privacy = 'Privacy';
  static const String linkFailed = 'Could not open that link.';

  static const String restore = 'Restore purchases';
  static const String restoreNothing = 'Nothing to restore on this account.';
  static const String manageLine =
      'Manage or cancel in your store account, any time.';

  // -- the code --------------------------------------------------------------

  static const String codePrompt = 'Have a code?';
  static const String codeTitle = 'Enter your code';
  static const String codeHint = 'Code';
  static const String codeCancel = 'Cancel';
  static const String codeApply = 'Unlock';
  static const String codeBad = "That code doesn't work.";
  static const String codeGood = 'Unlocked. Everything is yours.';

  // -- the state of things ---------------------------------------------------

  static const String activeTitle = "You're premium";
  static String activeLine(PremiumPlan plan) => switch (plan) {
    PremiumPlan.lifetime => 'Lifetime — thank you.',
    PremiumPlan.annual => 'Annual plan — thank you.',
    PremiumPlan.monthly => 'Monthly plan — thank you.',
  };

  /// Until the store's products exist, a purchase cannot be taken. Said
  /// plainly rather than with a spinner that goes nowhere.
  static const String storeSoon =
      'Payments are not open yet. Use a code for now.';
  static const String devUnlocked = 'Unlocked on this device (test build).';

  // -- what a locked thing says ---------------------------------------------

  static const String lockedChallenge = 'The 21-day challenge is premium.';
  static const String lockedJournal = 'The journal is premium.';
  static const String lockedImport = 'Importing a backup is premium.';
  static const String lockedWidget = 'This widget is premium.';
  static String lockedHabits(int limit) =>
      'Free keeps $limit habits. Premium has no limit.';
  static const String lockedSee = 'See premium';
}
