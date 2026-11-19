/// IMPORTANT: ship with real IDs only after your AdMob account is approved.
/// While [useTestAds] is true, Google's official test units are used, which is
/// the only safe way to develop (clicking your own live ads can get the
/// account banned).
const bool useTestAds = true;

// Google's public test IDs.
const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

// TODO: replace with your own ad unit IDs from the AdMob console.
const _liveBanner = 'ca-app-pub-2120666198065087/2092550444';
const _liveRewarded = 'ca-app-pub-2120666198065087/8793690160';

String get bannerUnitId => useTestAds ? _testBanner : _liveBanner;
String get rewardedUnitId => useTestAds ? _testRewarded : _liveRewarded;

/// Link shown in Settings. Host your privacy policy (see docs/privacy_policy.md).
const String privacyPolicyUrl = 'https://example.com/maqam-tuner/privacy';
