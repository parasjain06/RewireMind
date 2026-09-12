import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../content/app_content.dart';
import '../notifications/home_widget_service.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/link_row.dart';
import '../content/app_links.dart';
import 'onboarding_screen.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/illustrations.dart';
import '../widgets/k_card.dart';
import '../widgets/profile_photo.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'data_screen.dart';
import 'home_screen.dart';
import 'roadmap_screen.dart';
import 'test_app_screen.dart';
import 'widgets_screen.dart';
import 'notifications_screen.dart';
import 'profile_editor_sheet.dart';
import 'journal_screen.dart';
import '../content/premium_content.dart';
import 'premium_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    // Who you are and how you are doing stay put; only the settings list
    // moves. Scrolling your own streak off the top of your own profile was
    // the odd part.
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              6,
              k.geometry.screenPadding,
              0,
            ),
            child: Column(
              children: [
                const _ProfileHeader(),
                const SizedBox(height: 6),
                const _QuoteBar(),
                // Pinned with the header, not scrolled with the settings.
                // It is the one thing on this page somebody comes here to
                // start, and a card you have to find is a card you do not
                // start.
                const SizedBox(height: 14),
                const _ChallengeCard(),
              ],
            ),
          ),
        ),
        // A fixed gutter between the pinned part and the list. It used to be
        // the list's own top padding, which scrolls away with the content —
        // leaving the first card flush against the header the moment you
        // moved it.
        SizedBox(height: 12),
        // The card holds still and its rows move inside it. Scrolling the
        // whole white sheet made the page look like one long document that
        // happened to have a header stuck to it.
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              0,
              k.geometry.screenPadding,
              8,
            ),
            child: const _MenuList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// The user is the title of this screen, so the app name is not repeated
/// here. Kept to roughly the height of the Calendar and Progress headers so
/// moving between tabs does not feel like the page jumps.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final profile = context.watch<AppState>().profile;

    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -k.geometry.screenPadding,
            right: -k.geometry.screenPadding,
            bottom: 0,
            child: const MountainScene(height: 74),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _Avatar(),
                const SizedBox(width: 11),
                Flexible(
                  // Shrunk to fit rather than cut off. A name is the one piece
                  // of text on this page that belongs to the person reading
                  // it, and "Bartholom…" is a worse answer than small type.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      profile.name,
                      maxLines: 1,
                      style: k.text.sectionTitle.copyWith(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // A pencil beside the name replaces the "Edit profile" button:
                // same single entry point, a row of height cheaper.
                _EditButton(onTap: () => ProfileEditorSheet.show(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The way in to setting a profile picture.
///
/// The header circle rather than a row in a settings list: it is the thing on
/// screen that looks like a profile picture, so it is where somebody will try
/// to change one.
class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) =>
      ProfilePhoto(size: 64, onTap: () => chooseProfilePhoto(context));
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Material(
      color: k.colors.primarySoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.edit_outlined, size: 15, color: k.colors.primary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _QuoteBar extends StatelessWidget {
  const _QuoteBar();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final profile = context.watch<AppState>().profile;

    return KCard(
      soft: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 18, color: k.colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              profile.personalQuote,
              style: k.text.bodyStrong.copyWith(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The challenge, above the settings list rather than inside it.
///
/// It was a row among nine, between Account and Home Screen, which made the
/// one thing on this page you can actually *do* look like a preference. Given
/// its own card at the top it reads as an invitation, and it can show where
/// you have got to — which a settings row cannot.
/// The mark that says the challenge is running.
///
/// A small filled pill rather than a colour change: the card is already the
/// accent, so the only way to say "this one is live" on it is to put something
/// on top that was not there before.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
      ),
      child: Text(
        AppContent.challengeLive,
        style: k.text.captionStrong.copyWith(
          fontSize: 9,
          letterSpacing: 0.8,
          color: k.colors.primary,
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final live = context.select<AppState, bool>((s) => s.challengeLive);
    final done = context
        .select<AppState, int>((s) => s.challengeDay)
        .clamp(0, kPathLength);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(k.geometry.cardRadius),
      child: InkWell(
        onTap: () => openChallenge(context),
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(k.geometry.cardRadius),
            // Filled rather than outlined. Every other card on this page is a
            // white surface, so the accent is what makes this one read as the
            // thing to press.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [k.colors.accent, k.colors.primary],
            ),
            boxShadow: k.cardShadow,
          ),
          child: Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            AppContent.challengeCardTitle,
                            style: k.text.cardTitle.copyWith(
                              fontSize: 15.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (live) ...[
                          const SizedBox(width: 8),
                          const _LiveBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // An offer until it has been accepted. "Day 0 of 21"
                      // about a challenge nobody has joined reads as a failure
                      // rather than an invitation.
                      live
                          ? AppContent.pathStrip(done, kPathLength)
                          : AppContent.challengeNotStarted,
                      style: k.text.caption.copyWith(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    if (live) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: done / kPathLength,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.28),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 22, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // No "Home Screen" row where there is no home screen widget to add.
    final entries = [
      for (final entry in AppContent.profileMenu)
        if ((entry.id != 'widgets' || HomeWidgetService.supported) &&
            (entry.id != 'test_app' || kTestAppRow))
          entry,
    ];

    return KCard(
      padding: EdgeInsets.zero,
      // Clipped to the card's own corners, so a row scrolling past the top
      // disappears behind the rounded edge instead of over it.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _MenuRow(entry: entries[i]),
              if (i != entries.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 66, right: 14),
                  child: Divider(height: 1, color: k.colors.outline),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final ProfileMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // Nothing here wears a lock: what is paid for is found out by reaching
    // for it, not by being fenced off in advance.
    final premium = context.select<AppState, bool>((s) => s.isPremium);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Notifications is built; the rest land in later modules.
        onTap: () {
          if (entry.id == 'premium') {
            PremiumScreen.open(context);
            return;
          }
          if (entry.id == 'journal') {
            JournalScreen.open(context);
            return;
          }
          if (entry.id == 'notifications') {
            NotificationsScreen.open(context);
            return;
          }
          if (entry.id == 'appearance') {
            AppearanceScreen.open(context);
            return;
          }
          if (entry.id == 'challenge') {
            openChallenge(context);
            return;
          }
          if (entry.id == 'widgets') {
            WidgetsScreen.open(context);
            return;
          }
          if (entry.id == 'privacy') {
            DataScreen.open(context);
            return;
          }
          if (entry.id == 'onboarding') {
            OnboardingScreen.open(context);
            return;
          }
          if (entry.id == 'rate') {
            openLink(
              context,
              url: Uri.parse(AppLinks.rateNative),
              fallback: Uri.parse(AppLinks.rateWeb),
              failure: AppContent.linkFailed,
            );
            return;
          }
          if (entry.id == 'share_app') {
            SharePlus.instance.share(
              ShareParams(text: AppContent.shareAppText(AppLinks.rateWeb)),
            );
            return;
          }
          if (entry.id == 'feedback') {
            _sendFeedback(context);
            return;
          }
          if (entry.id == 'test_app') {
            TestAppScreen.open(context);
            return;
          }
          if (entry.id == 'about') {
            AboutScreen.open(context);
            return;
          }
          showAppSnackBar(
            context,
            message: '${entry.title} — coming soon',
            duration: const Duration(milliseconds: 1400),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              IconChip(
                iconKey: entry.iconKey,
                icon: AppIcons.forKey(entry.iconKey),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      style: k.text.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.id == 'premium' && premium
                          ? PremiumContent.menuLineActive
                          : entry.subtitle,
                      style: k.text.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: k.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mail draft to the feedback address, with the build already in it, so a
/// note arrives with the version it came from.
Future<void> _sendFeedback(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  await openLink(
    context,
    url: AppLinks.feedback('${info.version} (${info.buildNumber})'),
    failure: '${AppContent.helpNoMail}${AppLinks.feedbackEmail}',
  );
}
