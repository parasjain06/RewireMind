import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/day_phase.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/k_card.dart';

/// How the app decides which time of day to paint itself.
///
/// By default it reads the clock: peach until ten, blue until seven, dark
/// after. That is the right default and it is what most people will leave on.
/// It is not right for everyone, though — somebody who works nights gets a
/// bright page at four in the morning, and somebody who simply prefers the
/// dark palette has no way to ask for it. This screen is that way.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AppearanceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final manual = state.fixedPhase != null;

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
            AppContent.appearanceTitle,
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
            const _ManualCard(),
            // The choice only exists once the switch is on, rather than
            // sitting there greyed out: a disabled radio list reads as
            // something broken.
            if (manual) ...[
              const SizedBox(height: 14),
              for (final phase in DayPhase.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PhaseRow(phase: phase),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ManualCard extends StatelessWidget {
  const _ManualCard();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final manual = state.fixedPhase != null;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppContent.manualPhaseTitle, style: k.text.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      manual
                          ? AppContent.manualPhaseOn
                          : AppContent.manualPhaseOff,
                      style: k.text.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: manual,
                activeThumbColor: Colors.white,
                activeTrackColor: k.colors.accent,
                // Turning it on starts from whatever is on screen, so nothing
                // jumps at the moment of switching; turning it off hands the
                // page straight back to the clock.
                onChanged: (on) =>
                    state.setFixedPhase(on ? state.activePhase : null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One time of day, with a swatch of what the page will actually look like.
///
/// The swatch is the phase's own sky and its own accent, read from the live
/// theme rather than hard-coded, so it cannot drift from the thing it is
/// promising.
class _PhaseRow extends StatelessWidget {
  const _PhaseRow({required this.phase});

  final DayPhase phase;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final chosen = state.fixedPhase == phase;

    final preview = state.baseTheme.forPhase(phase);
    final sky = preview.colors.backgroundGradient;

    return KCard(
      onTap: () => state.setFixedPhase(phase),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: sky,
              ),
              border: Border.all(color: k.colors.accentTrack),
            ),
            child: Center(
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: preview.colors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(phase.label, style: k.text.cardTitle),
                const SizedBox(height: 1),
                Text(
                  AppContent.phaseHours(phase),
                  style: k.text.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            chosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 21,
            color: chosen ? k.colors.accent : k.colors.textMuted,
          ),
        ],
      ),
    );
  }
}
