import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/tone_service.dart';
import 'core/instruments.dart';
import 'core/maqam.dart';
import 'core/tuning_system.dart';
import 'l10n/l10n.dart';
import 'monetization/ads_service.dart';
import 'monetization/billing_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.prefs, this.billing, this.ads, this.tones) {
    a4 = prefs.getDouble('a4') ?? 440.0;
    system = TuningSystem.byDivisions(prefs.getInt('system') ?? 12);
    naming = NoteNaming.values[(prefs.getInt('naming') ?? 0).clamp(0, 1)];
    instrumentId = prefs.getString('instrument') ?? 'chromatic';
    maqamId = prefs.getString('maqam') ?? 'off';
    tonicPos = prefs.getInt('tonic') ?? 6;
    customNotes = prefs.getString('custom_notes') ?? 'C2 F2 A2 D3 G3 C4';
    sensitivity = (prefs.getInt('sensitivity') ?? 1).clamp(0, 2);
    haptics = prefs.getBool('haptics') ?? true;
    successCount = prefs.getInt('success_count') ?? 0;
    language = prefs.getString('lang') ?? 'system';
    L10n.i.setPreference(language);
    final ru = prefs.getInt('reward_until');
    if (ru != null) rewardedUntil = DateTime.fromMillisecondsSinceEpoch(ru);
    billing.addListener(notifyListeners);
    ads.addListener(notifyListeners);
  }

  final SharedPreferences prefs;
  final BillingService billing;
  final AdsService ads;
  final ToneService tones;

  late double a4;
  late TuningSystem system;
  late NoteNaming naming;
  late String instrumentId;
  late String maqamId;
  late int tonicPos;
  late String customNotes;
  late int sensitivity;
  late bool haptics;
  late int successCount;
  late String language; // 'system', 'en', 'tr' or 'ar'
  DateTime? rewardedUntil;

  /// Tapped string in instrument mode. Not persisted. null = auto-detect.
  String? lockedString;

  bool get rewardActive =>
      rewardedUntil != null && rewardedUntil!.isAfter(DateTime.now());
  bool get isPro => billing.hasPro || rewardActive;
  bool get adsRemoved => billing.hasRemoveAds || isPro;

  /// null = chromatic mode (no instrument).
  Instrument? get instrument {
    if (instrumentId == 'chromatic') return null;
    if (instrumentId == 'custom') {
      if (!isPro) return null;
      final inst = customInstrument;
      return inst.strings.isEmpty ? null : inst;
    }
    for (final i in builtInInstruments) {
      if (i.id == instrumentId) return (i.pro && !isPro) ? null : i;
    }
    return null;
  }

  /// Active scale (maqam practice mode); null if off or locked behind Pro.
  Maqam? get maqam {
    final m = maqamById(maqamId);
    if (m == null) return null;
    return (m.pro && !isPro) ? null : m;
  }

  Instrument get customInstrument => Instrument.fromNotes(
    'custom',
    'Custom',
    customNotes.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList(),
    pro: true,
  );

  void setA4(double v) {
    a4 = v.clamp(415.0, 466.0);
    prefs.setDouble('a4', a4);
    notifyListeners();
  }

  void setSystem(TuningSystem s) {
    system = s;
    prefs.setInt('system', s.divisions);
    notifyListeners();
  }

  void setNaming(NoteNaming n) {
    naming = n;
    prefs.setInt('naming', n.index);
    notifyListeners();
  }

  /// Selecting an instrument turns scale mode off (and vice versa).
  void setInstrument(String id) {
    instrumentId = id;
    lockedString = null;
    if (id != 'chromatic') {
      maqamId = 'off';
      prefs.setString('maqam', 'off');
    }
    prefs.setString('instrument', id);
    notifyListeners();
  }

  void setMaqam(String id, {int? tonic}) {
    maqamId = id;
    final m = maqamById(id);
    if (m != null) {
      final choices = tonicChoices(m.divisions);
      tonicPos =
          tonic ??
          (choices.contains(tonicPos) ? tonicPos : defaultTonic(m.divisions));
      instrumentId = 'chromatic';
      lockedString = null;
      prefs.setString('instrument', 'chromatic');
      prefs.setInt('tonic', tonicPos);
    }
    prefs.setString('maqam', id);
    notifyListeners();
  }

  void setTonic(int pos) {
    tonicPos = pos;
    prefs.setInt('tonic', pos);
    notifyListeners();
  }

  void lockString(String? label) {
    lockedString = label;
    notifyListeners();
  }

  void setCustomNotes(String s) {
    customNotes = s;
    prefs.setString('custom_notes', s);
    notifyListeners();
  }

  void setSensitivity(int v) {
    sensitivity = v;
    prefs.setInt('sensitivity', v);
    notifyListeners();
  }

  void setLanguage(String code) {
    language = code;
    prefs.setString('lang', code);
    L10n.i.setPreference(code);
    notifyListeners();
  }

  void setHaptics(bool v) {
    haptics = v;
    prefs.setBool('haptics', v);
    notifyListeners();
  }

  /// Called after a note was held in tune. After a handful of successes the
  /// Play in-app review dialog is requested (at most once per 120 days), so
  /// the rating prompt only reaches people whose tuning just worked.
  Future<void> registerSuccess() async {
    successCount++;
    prefs.setInt('success_count', successCount);
    if (successCount < 5) return;
    final last = prefs.getInt('review_asked') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < const Duration(days: 120).inMilliseconds) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await prefs.setInt('review_asked', now);
        await review.requestReview();
      }
    } catch (_) {}
  }

  /// Re-evaluate time-limited entitlements (rewarded Pro expiry).
  void refresh() => notifyListeners();

  /// Watch a rewarded ad -> 24 h of Pro features.
  Future<bool> claimRewardedPro() async {
    final earned = await ads.showRewarded();
    if (earned) {
      rewardedUntil = DateTime.now().add(const Duration(hours: 24));
      prefs.setInt('reward_until', rewardedUntil!.millisecondsSinceEpoch);
      notifyListeners();
    }
    return earned;
  }
}
