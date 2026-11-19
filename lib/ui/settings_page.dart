import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/tuning_system.dart';
import '../l10n/l10n.dart';
import '../l10n/tx.dart';
import '../monetization/ad_ids.dart';
import 'diagnostics_page.dart';
import 'paywall_page.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final pad = width < 360 ? 14.0 : 20.0;
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              Tx('Settings', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              Text(
                L10n.i.fmt('Reference pitch  A4 = {0} Hz', [state.a4.round()]),
                style: const TextStyle(fontSize: 16),
              ),
              Slider(
                value: state.a4.roundToDouble(),
                min: 415,
                max: 466,
                divisions: 51,
                label: '${state.a4.round()} Hz',
                onChanged: state.setA4,
              ),
              const Tx(
                '440 is standard. 415 is common for baroque ensembles.',
                style: TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 22),
              const Tx('Note names', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ChoiceRow<NoteNaming>(
                options: const [
                  (NoteNaming.letters, 'C D E'),
                  (NoteNaming.solfege, 'Do Re Mi'),
                ],
                value: state.naming,
                onChanged: state.setNaming,
              ),
              const SizedBox(height: 26),
              const Tx(
                'Microphone sensitivity',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Tx(
                'If the needle jumps around, pick Noisy room. If a soft note is not picked up, pick Quiet room.',
                style: TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ChoiceRow<int>(
                options: const [
                  (0, 'Noisy room'),
                  (1, 'Normal'),
                  (2, 'Quiet room'),
                ],
                value: state.sensitivity,
                onChanged: state.setSensitivity,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Tx('Vibrate when in tune'),
                value: state.haptics,
                onChanged: state.setHaptics,
              ),
              const SizedBox(height: 14),
              const Tx('Language', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ChoiceRow<String>(
                options: const [
                  ('system', 'System default'),
                  ('en', 'English'),
                  ('tr', 'Türkçe'),
                  ('ar', 'العربية'),
                ],
                value: state.language,
                onChanged: state.setLanguage,
              ),
              const SizedBox(height: 26),
              const Tx('Custom tuning', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Tx(
                state.isPro
                    ? 'Open-string notes, e.g. "C2 F2 A2 D3 G3 C4". Use # or b for accidentals, d for half-flat and s for half-sharp ("Bd3" = B half-flat).'
                    : 'Pro feature: enter the open-string notes of any instrument.',
                style: const TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _CustomField(state: state),
              const SizedBox(height: 26),
              Container(
                decoration: BoxDecoration(
                  color: Palette.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.line),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.workspace_premium,
                    color: Palette.brass,
                  ),
                  title: Tx(
                    state.isPro ? 'Pro is active' : 'Pro and Remove ads',
                  ),
                  subtitle: Tx(
                    state.isPro
                        ? 'Manage or restore purchases'
                        : 'Extra instruments, custom tunings, no ads',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PaywallPage(state: state),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fact_check_outlined),
                title: const Tx('Test the tuner on this phone'),
                subtitle: const Tx(
                  'Checks the app on your phone. No instrument needed.',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DiagnosticsPage(state: state),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: const Tx('How to read the notes'),
                onTap: () => _showHelp(context),
              ),
              FutureBuilder<bool>(
                future: state.ads.privacyOptionsRequired,
                builder: (context, snap) => snap.data == true
                    ? ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Tx('Ad privacy choices'),
                        onTap: state.ads.showPrivacyOptions,
                      )
                    : const SizedBox.shrink(),
              ),
              /*ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Tx('Privacy policy'),
                onTap: () => launchUrl(
                  Uri.parse(privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 8),
              const Tx(
                'Audio is processed on your device only. It is never recorded or sent anywhere.',
                style: TextStyle(color: Palette.muted, fontSize: 13),
              ),*/
            ],
          ),
        );
      },
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        title: const Tx('How to read the notes'),
        content: const SingleChildScrollView(
          child: Tx(
            'Note names are A, B, C… In 24-TET, + means a quarter tone sharp and − a quarter tone flat (E− is E half-flat). In 53-TET a note shows its distance in komas (1 koma is about 22.6 cents): 4 komas = bakiye, 5 = küçük mücenneb, 8 = büyük mücenneb. A cent is 1/100 of a semitone. The needle shows how many cents you are from the target.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Close'),
          ),
        ],
      ),
    );
  }
}

class _CustomField extends StatefulWidget {
  const _CustomField({required this.state});
  final AppState state;
  @override
  State<_CustomField> createState() => _CustomFieldState();
}

class _CustomFieldState extends State<_CustomField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.state.customNotes,
  );
  String? _error;

  void _commit(String v) {
    final parts = v
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final bad = parts.where((p) => noteToSemitones(p) == null).toList();
    setState(
      () => _error = (parts.isEmpty || bad.isNotEmpty)
          ? L10n.i.fmt('Not a valid note: {0}', [
              bad.isEmpty ? '(empty)' : bad.first,
            ])
          : null,
    );
    if (_error == null) widget.state.setCustomNotes(v.trim());
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      enabled: widget.state.isPro,
      onChanged: _commit,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: 'C2 F2 A2 D3 G3 C4',
        errorText: _error,
        errorMaxLines: 2,
        filled: true,
        fillColor: Palette.panel,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
