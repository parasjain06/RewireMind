import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rewiremind/content/premium_content.dart';
import 'package:rewiremind/models/premium.dart';
import 'package:rewiremind/screens/premium_screen.dart';

import 'helpers.dart';

/// What the free tier holds, what it costs to pass it, and the one code that
/// passes it without paying.
void main() {
  group('prices', () {
    test('India has its own, and everywhere else is in dollars', () {
      expect(PremiumPrices.forCountry('IN'), PremiumPrices.india);
      expect(PremiumPrices.forCountry('in'), PremiumPrices.india);
      expect(PremiumPrices.forCountry('US'), PremiumPrices.world);
      expect(PremiumPrices.forCountry(null), PremiumPrices.world);
    });

    test('a year costs less than twelve months, and says by how much', () {
      expect(PremiumPrices.india.priceOf(PremiumPlan.monthly), '₹80');
      expect(PremiumPrices.india.priceOf(PremiumPlan.annual), '₹300');
      expect(PremiumPrices.india.priceOf(PremiumPlan.lifetime), '₹700');
      expect(PremiumPrices.india.annualSaving, 69);
      expect(PremiumPrices.world.priceOf(PremiumPlan.lifetime), r'$60');
      expect(PremiumPrices.world.annualSaving, 86);
    });
  });

  group('the free tier', () {
    test('keeps five habits, and premium has no limit', () async {
      final state = await emptyState();
      for (var i = 1; i <= kFreeHabitLimit; i++) {
        expect(state.canAddHabit, isTrue, reason: 'habit $i is free');
        await state.addHabit(
          name: 'Habit $i',
          iconKey: 'walk',
          target: 1,
          unit: '',
        );
      }
      expect(state.canAddHabit, isFalse, reason: 'the sixth is not');

      await state.unlockPremium(PremiumPlan.monthly);
      expect(state.canAddHabit, isTrue);
    });

    test('the tester code unlocks it, and nothing else does', () async {
      final state = await emptyState();
      expect(state.isPremium, isFalse);

      expect(await state.redeemPremiumCode('rewire'), isFalse);
      expect(state.isPremium, isFalse);

      expect(await state.redeemPremiumCode('  ReWireMind@2026 '), isTrue);
      expect(state.isPremium, isTrue);
      expect(state.premium.plan, PremiumPlan.lifetime);

      // And it is still premium after a restart.
      final again = await reopen();
      expect(again.isPremium, isTrue);
    });

    test('signing in as the tester unlocks it too', () async {
      final state = await emptyState();
      await state.updateProfile(
        state.profile.copyWith(name: PremiumStatus.testCode),
      );
      expect(state.isPremium, isTrue);
    });
  });

  testWidgets('a locked thing opens the page, saying which', (tester) async {
    final state = await emptyState();
    await pumpAppWith(tester, state);

    PremiumScreen.open(
      tester.element(find.byType(Scaffold).first),
      note: PremiumContent.lockedJournal,
    );
    await tester.pumpAndSettle();

    expect(find.text(PremiumContent.title), findsWidgets);
    expect(find.text(PremiumContent.lockedJournal), findsOneWidget);
    // What the money buys.
    for (final perk in PremiumContent.perks) {
      expect(find.text(perk.title), findsOneWidget);
    }

    expect(find.text(PremiumContent.offerTitle), findsOneWidget);

    // The plans are further down the list.
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    for (final plan in PremiumPlan.values) {
      expect(find.text(PremiumContent.planName(plan)), findsOneWidget);
    }
    expect(find.text(PremiumContent.bestValue), findsOneWidget);
    // The launch offer: every plan shows what it is down from, and the strip
    // says how long that lasts.
    if (PremiumOffer.on) {
      for (final plan in PremiumPlan.values) {
        expect(
          find.text(PremiumPrices.world.regularOf(plan)),
          findsOneWidget,
          reason: 'the price it is down from',
        );
      }
    }
    // Both stores want these on the page itself.
    expect(find.text(PremiumContent.restore), findsOneWidget);
    expect(find.text(PremiumContent.terms), findsOneWidget);
    expect(find.text(PremiumContent.privacy), findsOneWidget);
    expect(find.text(PremiumContent.renewalTerms), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
