import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium.dart';

/// ============================================================================
/// THE STORE
/// ============================================================================
/// Buying premium, through Google Play or the App Store.
///
/// There is no redirect and no web page: [buy] hands the plan to the store,
/// the store draws its own sheet over the app, takes the payment against the
/// account already signed in there, and answers on [_iap.purchaseStream].
/// Everything this app does about a purchase happens in that listener.
///
/// What has to exist outside this file for it to work:
///
///   * the three products, created in the Play Console and App Store Connect
///     under exactly the ids below — two subscriptions and one non-consumable;
///   * their prices, set per country in those consoles (which is where ₹ and $
///     actually come from — [PremiumPrices] is only what the page shows until
///     the store answers);
///   * a build uploaded to a test track, signed with the release key, and the
///     tester's account allowed to buy it. A sideloaded APK cannot open the
///     purchase sheet, whatever this code does.
///
/// Entitlement is kept on the device. A receipt should be checked against the
/// Play Developer API or the App Store Server API before it is trusted, which
/// needs a server; until there is one, a rooted phone can fake a purchase.
/// That is a known and deliberate limit, not an oversight.
/// ============================================================================
class Billing {
  Billing._();

  static final Billing instance = Billing._();

  /// The product ids. Subscriptions first, then the one-off.
  static const String monthlyId = 'rewiremind_premium_monthly';
  static const String annualId = 'rewiremind_premium_annual';
  static const String lifetimeId = 'rewiremind_lifetime';

  static const Map<PremiumPlan, String> ids = {
    PremiumPlan.monthly: monthlyId,
    PremiumPlan.annual: annualId,
    PremiumPlan.lifetime: lifetimeId,
  };

  static PremiumPlan? planOf(String id) {
    for (final entry in ids.entries) {
      if (entry.value == id) return entry.key;
    }
    return null;
  }

  /// False where there is no store to talk to: tests, desktop, the web.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Reached for only behind [supported]: the Android implementation opens a
  /// connection to Play the moment it is constructed, and under a test — or on
  /// a desktop — there is nothing on the other end of that channel.
  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _watch;

  /// What the store says each plan costs, once it has been asked. Empty until
  /// then, and empty for good where the products do not exist yet.
  final Map<PremiumPlan, ProductDetails> products = {};

  bool _storeReady = false;
  bool get storeReady => _storeReady;

  /// Called with the plan whenever the store says it is owned — a fresh
  /// purchase, or one restored on a new phone.
  void Function(PremiumPlan plan)? onOwned;

  /// Called when a purchase fails or is cancelled, with something to show.
  void Function(String message)? onFailed;

  /// Starts listening. Safe to call more than once.
  Future<void> start() async {
    if (!supported || _watch != null) return;
    _watch = _iap.purchaseStream.listen(
      _handle,
      onError: (_) {},
      onDone: () => _watch?.cancel(),
    );
    _storeReady = await _iap.isAvailable();
    if (_storeReady) await load();
  }

  /// Asks the store what the plans cost, in the buyer's own currency.
  Future<void> load() async {
    if (!supported || !_storeReady) return;
    final response = await _iap.queryProductDetails(ids.values.toSet());
    for (final detail in response.productDetails) {
      final plan = planOf(detail.id);
      if (plan != null) products[plan] = detail;
    }
  }

  /// Opens the store's purchase sheet for [plan].
  ///
  /// False when there was nothing to open — no store, or the product has not
  /// been created yet — so the caller can say so rather than wait for an
  /// answer that is not coming.
  Future<bool> buy(PremiumPlan plan) async {
    if (!supported || !_storeReady) return false;
    final product = products[plan];
    if (product == null) return false;

    final param = PurchaseParam(productDetails: product);
    // Both the subscriptions and the lifetime unlock are non-consumable: they
    // are owned once and stay owned, which is what the store's own record of
    // them should say.
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Replays what this account already owns, so a new phone — or an app that
  /// was deleted and installed again — comes back unlocked.
  ///
  /// Apple requires this to be reachable from the app, which is what the
  /// button on the premium page is for.
  Future<void> restore() async {
    if (!supported || !_storeReady) return;
    await _iap.restorePurchases();
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          onFailed?.call(purchase.error?.message ?? '');
        case PurchaseStatus.canceled:
          onFailed?.call('');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final plan = planOf(purchase.productID);
          if (plan != null) onOwned?.call(plan);
      }
      // Required by both stores, and by Play within three days or the money
      // goes back: the purchase is not finished until this is called.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> dispose() async {
    await _watch?.cancel();
    _watch = null;
  }
}
