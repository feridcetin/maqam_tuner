import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play Billing wrapper.
///
/// Products to create in Play Console (Monetize > Products):
///  - remove_ads    : one-time product (non-consumable)
///  - pro_lifetime  : one-time product (non-consumable) -> Pro forever
///  - pro_yearly    : subscription
/// Users of tuner apps repeatedly complain about subscription-only pricing,
/// so every paid feature has a one-time option.
class BillingService extends ChangeNotifier {
  BillingService(this._prefs);
  final SharedPreferences _prefs;

  static const removeAdsId = 'remove_ads';
  static const proLifetimeId = 'pro_lifetime';
  static const proYearlyId = 'pro_yearly';
  static const _ids = {removeAdsId, proLifetimeId, proYearlyId};

  /// A subscription is trusted for this long after Play last confirmed it.
  /// Play re-confirms active subscriptions at every app start.
  static const _proGrace = Duration(days: 14);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool storeAvailable = false;
  bool busy = false;
  String? message;
  Map<String, ProductDetails> products = {};

  bool get hasRemoveAds => _prefs.getBool('ent_remove_ads') ?? false;

  bool get hasPro {
    if (_prefs.getBool('ent_pro_lifetime') ?? false) return true;
    final ts = _prefs.getInt('ent_pro_ts');
    if (ts == null) return false;
    return DateTime.now().millisecondsSinceEpoch - ts <
        _proGrace.inMilliseconds;
  }

  Future<void> init() async {
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        message = '$e';
        busy = false;
        notifyListeners();
      },
    );
    try {
      storeAvailable = await _iap.isAvailable();
      if (storeAvailable) {
        final r = await _iap.queryProductDetails(_ids);
        products = {for (final p in r.productDetails) p.id: p};
        await _iap.restorePurchases();
      }
    } catch (e) {
      message = '$e';
    }
    notifyListeners();
  }

  Future<void> buy(String id) async {
    final p = products[id];
    if (p == null) {
      message = 'This product is not available yet.';
      notifyListeners();
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: p),
      );
    } catch (e) {
      busy = false;
      message = '$e';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    message = null;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      message = '$e';
    }
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy = true;
        case PurchaseStatus.error:
          busy = false;
          message = p.error?.message ?? 'Purchase failed.';
        case PurchaseStatus.canceled:
          busy = false;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          busy = false;
          await _grant(p.productID);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    notifyListeners();
  }

  Future<void> _grant(String productId) async {
    if (productId == removeAdsId) {
      await _prefs.setBool('ent_remove_ads', true);
    } else if (productId == proLifetimeId) {
      await _prefs.setBool('ent_pro_lifetime', true);
    } else if (productId == proYearlyId) {
      await _prefs.setInt('ent_pro_ts', DateTime.now().millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
