import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

class AdsService extends ChangeNotifier {
  bool ready = false;
  RewardedAd? _rewarded;

  /// Runs the EU/UK consent flow (Google UMP) and then starts the Ads SDK.
  Future<void> init() async {
    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (!consentDone.isCompleted) consentDone.complete();
        });
      },
      (FormError e) {
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );
    await consentDone.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {},
    );

    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
      ready = true;
      _loadRewarded();
      notifyListeners();
    }
  }

  Future<bool> get privacyOptionsRequired async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) => done.complete());
    await done.future;
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => _rewarded = null,
      ),
    );
  }

  bool get rewardedAvailable => _rewarded != null;

  /// Shows a rewarded ad. Completes with true only if the user earned the reward.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return done.future;
  }
}
