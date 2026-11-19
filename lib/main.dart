import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'audio/tone_service.dart';
import 'audio/tuner_controller.dart';
import 'l10n/l10n.dart';
import 'monetization/ads_service.dart';
import 'monetization/billing_service.dart';
import 'ui/banner_ad_widget.dart';
import 'ui/settings_page.dart';
import 'ui/theme.dart';
import 'ui/tone_page.dart';
import 'ui/tuner_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The tuner layout is designed for portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  L10n.i.setSystemLanguage(
    WidgetsBinding.instance.platformDispatcher.locale.languageCode,
  );
  final prefs = await SharedPreferences.getInstance();
  final billing = BillingService(prefs);
  final ads = AdsService();
  final state = AppState(prefs, billing, ads, ToneService());

  runApp(MaqamApp(state: state));

  // Start services after the first frame so the UI appears immediately.
  unawaited(billing.init());
  unawaited(ads.init());
}

class MaqamApp extends StatelessWidget {
  const MaqamApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: L10n.i,
    builder: (context, _) => MaterialApp(
      title: 'Maqam Tuner',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Arabic is right-to-left. Text scale is capped so large system fonts
      // cannot push the layout off small screens.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return Directionality(
          textDirection: L10n.i.rtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.25,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: HomeShell(state: state),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final TunerController _tuner = TunerController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncSensitivity();
    widget.state.addListener(_syncSensitivity);
  }

  void _syncSensitivity() => _tuner.sensitivity = widget.state.sensitivity;

  @override
  void didChangeLocales(List<Locale>? locales) {
    L10n.i.setSystemLanguage(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      widget.state.refresh(); // re-check time-limited rewards
      if (_tab == 0) _tuner.resume();
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.hidden ||
        s == AppLifecycleState.detached) {
      // "inactive" is deliberately ignored: the microphone permission dialog
      // and the notification shade trigger it, and must not stop the tuner.
      _tuner.suspend();
      widget.state.tones.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.removeListener(_syncSensitivity);
    _tuner.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i != 0) _tuner.suspend();
    if (i == 0) _tuner.resume();
    if (i != 1) widget.state.tones.stop();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      backgroundColor: Palette.bg,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                TunerPage(state: state, tuner: _tuner),
                TonePage(state: state),
                SettingsPage(state: state),
              ],
            ),
          ),
          // No ads while the tuner is actively listening: the most common
          // complaint about competing tuner apps. The banner stays loaded (not
          // disposed) so hiding it does not trigger new ad requests.
          ListenableBuilder(
            listenable: _tuner,
            builder: (context, child) => Visibility(
              visible: !(_tab == 0 && _tuner.listening),
              maintainState: true,
              child: child!,
            ),
            child: Center(child: BannerAdWidget(state: state)),
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: L10n.i,
        builder: (context, _) => NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.mic_none),
              selectedIcon: const Icon(Icons.mic),
              label: L10n.i.t('Tuner'),
              tooltip: '',
            ),
            NavigationDestination(
              icon: const Icon(Icons.graphic_eq),
              label: L10n.i.t('Tone'),
              tooltip: '',
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune),
              label: L10n.i.t('Settings'),
              tooltip: '',
            ),
          ],
        ),
      ),
    );
  }
}
