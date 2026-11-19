import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

import '../app_state.dart';
import '../monetization/ad_ids.dart';

/// Anchored adaptive banner. Hidden for users who removed ads or have Pro.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key, required this.state});
  final AppState state;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (!mounted) return;
    if (widget.state.adsRemoved) {
      _ad?.dispose();
      _ad = null;
      setState(() {});
      return;
    }
    if (_ad != null || _loading || !widget.state.ads.ready) return;
    _loading = true;
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (size == null || !mounted) {
      _loading = false;
      return;
    }
    BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loading = false;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _ad = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          _loading = false;
          ad.dispose();
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    widget.state.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || widget.state.adsRemoved) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
