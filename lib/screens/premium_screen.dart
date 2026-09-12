import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/app_links.dart';
import '../content/premium_content.dart';
import '../data/billing.dart';
import '../data/region.dart';
import '../models/premium.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/k_card.dart';
import '../widgets/link_row.dart';
import 'test_app_screen.dart' show kTestAppRow;

/// What the paid tier is, and the three ways to have it.
///
/// One page, and all of it on one screen: what is included, the three plans
/// with the launch offer against them, and a button. A paywall that has to be
/// scrolled is a paywall whose prices somebody has not seen.
///
/// Prices come from the store as soon as it answers — formatted in the
/// buyer's own currency, by the country their store account is in, which is
/// the only authority on what they will actually be charged. [PremiumPrices]
/// is what the page shows until then.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.note});

  /// Why this page opened — the line from whatever was locked. Shown at the
  /// top, so landing here never feels like a non sequitur.
  final String? note;

  static Future<void> open(BuildContext context, {String? note}) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PremiumScreen(note: note)));
  }

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  /// Lifetime first: it is the one the page recommends, and a page that opens
  /// on its cheapest plan is selling the cheapest plan.
  PremiumPlan _plan = PremiumPlan.lifetime;

  /// Ticks the countdown, and nothing else.
  Timer? _clock;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Region.resolve().then((_) {
      if (mounted) setState(() {});
    });
    Billing.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    if (PremiumOffer.on) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  PremiumPrices get _prices => PremiumPrices.forCountry(Region.country);

  /// What one plan costs, in the store's own words where the store has
  /// answered.
  String _priceOf(PremiumPlan plan) =>
      Billing.instance.products[plan]?.price ?? _prices.priceOf(plan);

  Future<void> _buy() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);

    // The store's own sheet, over the app. Everything after this happens in
    // the purchase stream, which unlocks premium and pops this page.
    final opened = await Billing.instance.buy(_plan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (opened) return;

    // Nothing to open: the products do not exist yet, or there is no store on
    // this device. A test build unlocks anyway, so the paid app can be walked
    // through; a store build says where it stands rather than spinning.
    if (!kTestAppRow) {
      await showAppSnackBar(context, message: PremiumContent.storeSoon);
      return;
    }
    await state.unlockPremium(_plan, source: 'dev');
    if (!mounted) return;
    await showAppSnackBar(context, message: PremiumContent.devUnlocked);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restore() async {
    await Billing.instance.restore();
    if (!mounted) return;
    await showAppSnackBar(
      context,
      message: context.read<AppState>().isPremium
          ? PremiumContent.codeGood
          : PremiumContent.restoreNothing,
    );
  }

  Future<void> _redeem() async {
    final controller = TextEditingController();
    final k = context.k;
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(PremiumContent.codeTitle, style: k.text.cardTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: PremiumContent.codeHint,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              PremiumContent.codeCancel,
              style: k.text.captionStrong.copyWith(
                color: k.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(
              PremiumContent.codeApply,
              style: k.text.captionStrong.copyWith(color: k.colors.primary),
            ),
          ),
        ],
      ),
    );
    if (code == null || !mounted) return;

    final ok = await context.read<AppState>().redeemPremiumCode(code);
    if (!mounted) return;
    await showAppSnackBar(
      context,
      message: ok ? PremiumContent.codeGood : PremiumContent.codeBad,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final premium = context.watch<AppState>().premium;
    final pad = k.geometry.screenPadding;

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
            PremiumContent.title,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: SafeArea(
          top: false,
          child: premium.active
              ? ListView(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                  children: [_Owned(plan: premium.plan!)],
                )
              : Column(
                  children: [
                    // The page scrolls; the button does not. Which is the
                    // point of splitting them: the list can be as long as the
                    // list needs to be, and the price and the way to pay it
                    // are on screen the whole time.
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(pad, 4, pad, 16),
                        children: [
                          _Head(note: widget.note),
                          if (PremiumOffer.on) ...[
                            const SizedBox(height: 14),
                            const _Countdown(),
                          ],
                          const SizedBox(height: 18),
                          const _Perks(),
                          const SizedBox(height: 18),
                          for (final each in PremiumPlan.values) ...[
                            _PlanRow(
                              plan: each,
                              prices: _prices,
                              price: _priceOf(each),
                              selected: each == _plan,
                              onTap: () => setState(() => _plan = each),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                    _ActionBar(
                      plan: _plan,
                      busy: _busy,
                      onBuy: _buy,
                      onRestore: _restore,
                      onRedeem: _redeem,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The headline, and why this page opened.
///
/// No mascot: it is a price list, and the character standing over it made it
/// look like a game's shop rather than the app asking to be paid for.
class _Head extends StatelessWidget {
  const _Head({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PremiumContent.eyebrow,
          style: k.text.caption.copyWith(
            fontSize: 10.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: k.colors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          PremiumContent.heroLine,
          style: k.text.sectionTitle.copyWith(fontSize: 22, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          note ?? PremiumContent.heroSub,
          style: k.text.body.copyWith(
            fontSize: 13.5,
            color: k.colors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// How long the launch offer has left, to the second.
class _Countdown extends StatelessWidget {
  const _Countdown();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: k.colors.flame.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
        border: Border.all(color: k.colors.flame.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, size: 17, color: k.colors.flame),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PremiumContent.offerTitle,
              style: k.text.captionStrong.copyWith(fontSize: 12),
            ),
          ),
          // Tabular-ish: the seconds tick without the line jumping about.
          Text(
            PremiumContent.offerClock(PremiumOffer.left()),
            style: k.text.statValue.copyWith(
              fontSize: 13,
              color: k.colors.flame,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the money buys: one line each, with room around it.
class _Perks extends StatelessWidget {
  const _Perks();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PremiumContent.includedTitle,
            style: k.text.caption.copyWith(
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: k.colors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          for (final perk in PremiumContent.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k.colors.accentSoft,
                    ),
                    child: Icon(perk.icon, size: 17, color: k.colors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perk.title,
                          style: k.text.bodyStrong.copyWith(fontSize: 13.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          perk.line,
                          style: k.text.caption.copyWith(
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One plan: what it is called, what it runs for, and what it costs — with
/// the price it is down from, while the offer is on.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.prices,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlan plan;
  final PremiumPrices prices;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final best = plan == PremiumPlan.lifetime;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? k.colors.accentSoft : k.colors.surface,
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
          border: Border.all(
            color: selected ? k.colors.accent : k.colors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? k.colors.accent : k.colors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          PremiumContent.planName(plan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: k.text.cardTitle.copyWith(fontSize: 15),
                        ),
                      ),
                      if (best) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: k.colors.primary,
                            borderRadius: BorderRadius.circular(
                              k.geometry.pillRadius,
                            ),
                          ),
                          child: Text(
                            PremiumContent.bestValue,
                            style: k.text.caption.copyWith(
                              fontSize: 9.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PremiumContent.planNote(plan, prices),
                    style: k.text.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (PremiumOffer.on)
                  Text(
                    prices.regularOf(plan),
                    style: k.text.caption.copyWith(
                      fontSize: 11,
                      color: k.colors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(price, style: k.text.statValue.copyWith(fontSize: 19)),
                Text(
                  PremiumContent.planPer(plan),
                  style: k.text.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The button, and the small print both stores ask to see beside it.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.plan,
    required this.busy,
    required this.onBuy,
    required this.onRestore,
    required this.onRedeem,
  });

  final PremiumPlan plan;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onRestore;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final pad = k.geometry.screenPadding;

    return Container(
      padding: EdgeInsets.fromLTRB(pad, 10, pad, 8),
      decoration: BoxDecoration(
        color: k.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: k.colors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: busy ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: k.colors.primary,
                disabledBackgroundColor: k.colors.primary.withValues(
                  alpha: 0.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(k.geometry.pillRadius),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      PremiumContent.cta(plan),
                      style: k.text.cardTitle.copyWith(color: Colors.white),
                    ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _SmallLink(
                  label: PremiumContent.restore,
                  onTap: onRestore,
                ),
              ),
              Text('·', style: k.text.caption),
              Flexible(
                child: _SmallLink(
                  label: PremiumContent.codePrompt,
                  onTap: onRedeem,
                ),
              ),
            ],
          ),
          const _Legal(),
        ],
      ),
    );
  }
}

/// The renewal terms, and where to read the rest.
class _Legal extends StatelessWidget {
  const _Legal();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final style = k.text.caption.copyWith(fontSize: 9.5, height: 1.35);

    return Column(
      children: [
        Text(
          PremiumContent.renewalTerms,
          textAlign: TextAlign.center,
          style: style,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: _SmallLink(
                label: PremiumContent.terms,
                onTap: () => openLink(
                  context,
                  url: Uri.parse(AppLinks.terms),
                  failure: PremiumContent.linkFailed,
                ),
              ),
            ),
            Text('·', style: style),
            Flexible(
              child: _SmallLink(
                label: PremiumContent.privacy,
                onTap: () => openLink(
                  context,
                  url: Uri.parse(AppLinks.privacy),
                  failure: PremiumContent.linkFailed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallLink extends StatelessWidget {
  const _SmallLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: k.text.captionStrong.copyWith(
          fontSize: 11.5,
          color: k.colors.primary,
        ),
      ),
    );
  }
}

/// The page as somebody who has paid sees it.
class _Owned extends StatelessWidget {
  const _Owned({required this.plan});

  final PremiumPlan plan;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 26,
              color: k.colors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              PremiumContent.activeTitle,
              style: k.text.sectionTitle.copyWith(fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          PremiumContent.activeLine(plan),
          style: k.text.body.copyWith(color: k.colors.textSecondary),
        ),
        const SizedBox(height: 18),
        const _Perks(),
        const SizedBox(height: 14),
        Text(
          PremiumContent.manageLine,
          style: k.text.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
