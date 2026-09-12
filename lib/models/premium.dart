import 'package:flutter/foundation.dart';

/// ============================================================================
/// PREMIUM
/// ============================================================================
/// What is paid for, what it costs where, and whether this copy of the app has
/// it. The prices here are the ones the page shows; a real purchase comes back
/// from the store with its own, which is why they live in one table rather
/// than being typed into the page.
/// ============================================================================

/// How premium is bought.
enum PremiumPlan {
  monthly,
  annual,

  /// One payment, no renewal — the one most people pick when they have already
  /// decided, and the one this app is honest about being able to offer.
  lifetime,
}

/// What the plans cost in one currency.
@immutable
class PremiumPrices {
  const PremiumPrices({
    required this.symbol,
    required this.code,
    required this.monthly,
    required this.annual,
    required this.lifetime,
    required this.regularMonthly,
    required this.regularAnnual,
    required this.regularLifetime,
  });

  final String symbol;
  final String code;
  final int monthly;
  final int annual;
  final int lifetime;

  /// What each plan goes back to when the launch offer ends. These have to be
  /// the prices actually charged then — a line through a number nobody was
  /// ever asked for is a misleading price, and both stores treat it as one.
  final int regularMonthly;
  final int regularAnnual;
  final int regularLifetime;

  int of(PremiumPlan plan) => switch (plan) {
    PremiumPlan.monthly => monthly,
    PremiumPlan.annual => annual,
    PremiumPlan.lifetime => lifetime,
  };

  int regular(PremiumPlan plan) => switch (plan) {
    PremiumPlan.monthly => regularMonthly,
    PremiumPlan.annual => regularAnnual,
    PremiumPlan.lifetime => regularLifetime,
  };

  String priceOf(PremiumPlan plan) => '$symbol${of(plan)}';

  String regularOf(PremiumPlan plan) => '$symbol${regular(plan)}';

  /// What the annual plan saves against paying monthly for a year, as a
  /// percentage — nothing when it saves nothing.
  int? get annualSaving {
    final full = monthly * 12;
    if (full <= annual) return null;
    return ((full - annual) / full * 100).round();
  }

  static const PremiumPrices india = PremiumPrices(
    symbol: '₹',
    code: 'INR',
    monthly: 80,
    annual: 300,
    lifetime: 700,
    regularMonthly: 120,
    regularAnnual: 500,
    regularLifetime: 1200,
  );

  /// Everywhere else, in dollars.
  static const PremiumPrices world = PremiumPrices(
    symbol: r'$',
    code: 'USD',
    monthly: 30,
    annual: 50,
    lifetime: 60,
    regularMonthly: 45,
    regularAnnual: 80,
    regularLifetime: 100,
  );

  /// The table for a device in [country] (an ISO code, as the platform gives
  /// it). India has its own; the rest of the world is priced in dollars.
  ///
  /// A real store hands back the local price for each product, formatted for
  /// the buyer's country, and that is what the page should show once billing
  /// is wired up. This is what it shows until then.
  static PremiumPrices forCountry(String? country) =>
      (country ?? '').toUpperCase() == 'IN' ? india : world;
}

/// Whether this copy of the app is paid for, and how it came to be.
@immutable
class PremiumStatus {
  const PremiumStatus({this.plan, this.since, this.source = ''});

  /// Null while the app is on the free tier.
  final PremiumPlan? plan;
  final DateTime? since;

  /// Where it came from: a store purchase, or a code.
  final String source;

  bool get active => plan != null;

  static const PremiumStatus free = PremiumStatus();

  /// The tester's way in, so everything can be walked through without a
  /// payment: entered as a code on the premium page, or as the name at
  /// sign-in.
  static const String testCode = 'rewiremind@2026';

  static bool isTestCode(String input) =>
      input.trim().toLowerCase() == testCode;

  Map<String, dynamic> toJson() => {
    'plan': plan?.name,
    'since': since?.toIso8601String(),
    'source': source,
  };

  static PremiumStatus fromJson(Map<String, dynamic>? json) {
    if (json == null) return free;
    final name = json['plan'] as String?;
    if (name == null) return free;
    return PremiumStatus(
      plan: PremiumPlan.values.firstWhere(
        (p) => p.name == name,
        orElse: () => PremiumPlan.lifetime,
      ),
      since: DateTime.tryParse(json['since'] as String? ?? ''),
      source: json['source'] as String? ?? '',
    );
  }
}

/// The launch offer: a real window with a real end.
///
/// A countdown is not something either store draws — a store knows an
/// introductory price, not a clock — so if there is to be one it lives here.
/// Which makes it a promise: [endsAt] is when the prices in [PremiumPrices]
/// go up to their regular ones, and the store's own products have to be
/// repriced to match on that day, or the line through the old price is a lie.
/// Move the date to extend the offer; take it out to end it for good.
class PremiumOffer {
  const PremiumOffer._();

  static final DateTime endsAt = DateTime(2026, 9, 30);

  /// Lets a test stand somewhere in or out of the window.
  static DateTime Function() now = DateTime.now;

  static bool get on => now().isBefore(endsAt);

  static Duration left() {
    final gap = endsAt.difference(now());
    return gap.isNegative ? Duration.zero : gap;
  }
}

/// What the free tier holds.
///
/// Five is enough to build a real morning with — water, a walk, a book, an
/// early night — and the sixth is where somebody has decided the app is theirs.
const int kFreeHabitLimit = 5;
