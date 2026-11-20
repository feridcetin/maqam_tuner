import 'dart:math' show sqrt;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../audio/tuner_controller.dart';
import '../core/instruments.dart';
import '../core/maqam.dart';
import '../core/tuning_system.dart';
import 'paywall_page.dart';
import 'reading.dart';
import 'ruler_gauge.dart';
import '../l10n/tx.dart';
import '../l10n/l10n.dart';
import 'theme.dart';

class TunerPage extends StatefulWidget {
  const TunerPage({super.key, required this.state, required this.tuner});
  final AppState state;
  final TunerController tuner;

  @override
  State<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends State<TunerPage> {
  DateTime? _inTuneSince;
  bool _counted = false;
  int? _sticky; // last chromatic step shown (hysteresis)
  int _stickyDiv = 0;

  int? get _stickyStep => _stickyDiv == state.system.divisions ? _sticky : null;

  AppState get state => widget.state;
  TunerController get tuner => widget.tuner;

  @override
  void initState() {
    super.initState();
    tuner.addListener(_track);
  }

  @override
  void dispose() {
    tuner.removeListener(_track);
    super.dispose();
  }

  /// Detects "held in tune for 1 s": buzzes once and counts a success.
  void _track() {
    final r = computeReading(state, tuner.hz, stickyStep: _stickyStep);
    _sticky = r?.step;
    _stickyDiv = state.system.divisions;
    if (r != null && r.inTune) {
      final now = DateTime.now();
      _inTuneSince ??= now;
      if (!_counted && now.difference(_inTuneSince!).inMilliseconds >= 1000) {
        _counted = true;
        if (state.haptics) HapticFeedback.mediumImpact();
        state.registerSuccess();
      }
    } else {
      _inTuneSince = null;
      _counted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state, tuner]),
      builder: (context, _) {
        final inst = state.instrument;
        final maqam = state.maqam;
        final r = computeReading(state, tuner.hz, stickyStep: _stickyStep);
        final half =
            r?.half ??
            (inst != null
                ? 50.0
                : maqam != null
                ? 40.0
                : state.system.stepCents / 2);
        final tolerance = r?.tolerance ?? 5.0;
        final inTune = r?.inTune ?? false;

        final width = MediaQuery.sizeOf(context).width;
        final pad = width < 360 ? 14.0 : 20.0;
        final chipMax = width - 2 * pad;

        String hint;
        if (!tuner.listening) {
          hint = 'Tap Start and play a note';
        } else if (r == null) {
          hint = 'Listening… play one note at a time';
        } else if (inTune) {
          hint = 'In tune';
        } else {
          // A quarter tone sits exactly between two 12-TET notes: say so instead of
          // flip-flopping between "tune up" and "tune down".
          final between =
              inst == null &&
              maqam == null &&
              state.system.divisions == 12 &&
              r.cents.abs() >= 40;
          hint = between
              ? 'Between two notes. Try 24-TET for quarter tones.'
              : (r.cents < 0 ? 'Tune up' : 'Tune down');
        }

        final String subtitle;
        if (inst != null) {
          subtitle = L10n.i.fmt('{0} · targets in 12-TET', [
            L10n.i.t(inst.name),
          ]);
        } else if (maqam != null) {
          subtitle = L10n.i.fmt('{0} on {1} · {2}', [
            L10n.i.t(maqam.name),
            tonicName(maqam.divisions, state.tonicPos, state.naming),
            maqam.systemLabel,
          ]);
        } else {
          subtitle = L10n.i.t(state.system.description);
        }

        final centsText = r == null
            ? ''
            : '${r.cents > 0 ? '+' : ''}${r.cents.toStringAsFixed(1)}';

        return SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
            children: [
              _SystemSelector(state: state, enabled: maqam == null),
              const SizedBox(height: 4),
              Tx(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: chipMax),
                    child: ActionChip(
                      avatar: const Icon(Icons.queue_music, size: 18),
                      label: Tx(
                        inst?.name ?? 'Chromatic',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _pickInstrument(context),
                      backgroundColor: Palette.panel,
                      side: const BorderSide(color: Palette.line),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: chipMax),
                    child: ActionChip(
                      avatar: const Icon(Icons.timeline, size: 18),
                      label: Tx(
                        maqam == null
                            ? 'Scale: off'
                            : L10n.i.fmt('Scale: {0}', [L10n.i.t(maqam.name)]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _pickScale(context),
                      backgroundColor: Palette.panel,
                      side: BorderSide(
                        color: maqam == null ? Palette.line : Palette.brass,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // The big note shrinks to fit instead of overflowing on small screens.
              SizedBox(
                height: 116,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Tx(
                        r?.note ?? '—',
                        style: TextStyle(
                          fontSize: 104,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                          color: r == null
                              ? Palette.line
                              : (inTune ? Palette.ok : Palette.ivory),
                        ),
                      ),
                      if (r?.octave != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Tx(
                            r!.octave!,
                            style: const TextStyle(
                              fontSize: 30,
                              color: Palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: Center(
                  child: Tx(
                    r?.detail ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Palette.brass),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              RulerGauge(cents: r?.cents, half: half, tolerance: tolerance),
              const SizedBox(height: 6),
              SizedBox(
                height: 24,
                child: r == null
                    ? null
                    : Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Tx(
                            '${L10n.i.fmt('{0} cents', [centsText])}  ·  ${r.hz.toStringAsFixed(1)} Hz  →  ${r.targetHz.toStringAsFixed(1)} Hz',
                            maxLines: 1,
                            style: const TextStyle(
                              color: Palette.muted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Tx(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: inTune ? Palette.ok : Palette.ivory,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (sqrt(tuner.level) * 3).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Palette.line,
                  color: Palette.brass,
                ),
              ),
              if (inst != null) ...[
                const SizedBox(height: 18),
                Tx(
                  state.lockedString == null
                      ? 'Auto-detecting the string. Tap one to lock it and hear it.'
                      : L10n.i.fmt(
                          'Locked to {0}. Tap it again for auto-detect.',
                          [state.lockedString!],
                        ),
                  style: const TextStyle(color: Palette.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in inst.strings)
                      ChoiceChip(
                        label: Tx(s.label),
                        selected:
                            s.label == (state.lockedString ?? r?.stringLabel),
                        showCheckmark: false,
                        avatar: s.label == state.lockedString
                            ? const Icon(Icons.lock, size: 14)
                            : null,
                        onSelected: (_) {
                          if (state.lockedString == s.label) {
                            state.lockString(null);
                            state.tones.stop();
                          } else {
                            state.lockString(s.label);
                            // Do not "tune" the app's own speaker output.
                            tuner.muteFor(const Duration(milliseconds: 3300));
                            state.tones.pluck(s.hz(state.a4));
                          }
                        },
                        selectedColor: Palette.brass.withAlpha(70),
                        backgroundColor: Palette.panel,
                        side: const BorderSide(color: Palette.line),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              if (tuner.permissionDenied)
                const _Notice(
                  'Microphone access is off. Allow it in Android Settings > Apps > '
                  'Maqam Tuner > Permissions. Audio is analysed on your phone and never recorded.',
                ),
              if (tuner.error != null) _Notice(tuner.error!),
              FilledButton.icon(
                onPressed: () => tuner.listening ? tuner.stop() : tuner.start(),
                icon: Icon(tuner.listening ? Icons.stop : Icons.mic),
                label: Tx(tuner.listening ? 'Stop' : 'Start listening'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPaywall(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => PaywallPage(state: state)));

  void _pickInstrument(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Tx('Chromatic'),
              subtitle: const Tx('Nearest note in the chosen tuning system'),
              selected:
                  state.instrumentId == 'chromatic' && state.maqam == null,
              onTap: () {
                state.setInstrument('chromatic');
                state.setMaqam('off');
                Navigator.pop(ctx);
              },
            ),
            for (final i in builtInInstruments)
              _instrumentTile(
                ctx,
                context,
                i.id,
                i.name,
                i.strings.map((s) => s.label).join(' '),
                i.pro,
              ),
            _instrumentTile(
              ctx,
              context,
              'custom',
              'Custom tuning',
              state.customNotes,
              true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _instrumentTile(
    BuildContext sheet,
    BuildContext page,
    String id,
    String name,
    String strings,
    bool pro,
  ) {
    final locked = pro && !state.isPro;
    return ListTile(
      leading: Icon(locked ? Icons.lock_outline : Icons.music_note),
      title: Tx(name),
      subtitle: Tx(strings),
      selected: state.instrumentId == id,
      trailing: locked
          ? const Tx('Pro', style: TextStyle(color: Palette.brass))
          : null,
      onTap: () {
        Navigator.pop(sheet);
        if (locked) {
          _openPaywall(page);
        } else {
          state.setInstrument(id);
        }
      },
    );
  }

  void _pickScale(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: state,
        builder: (ctx, _) {
          final current = maqamById(state.maqamId);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and Done stay visible; only the list below scrolls.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Tx(
                            'Scale',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Tx('Done'),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Tx(
                      'Scale practice shows the nearest degree of a scale and how far '
                      'you are from it. Values are standard theoretical ones; '
                      'players and regions differ.',
                      style: TextStyle(color: Palette.muted, fontSize: 13),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Tx('Off'),
                    selected: state.maqamId == 'off',
                    onTap: () {
                      state.setMaqam('off');
                      Navigator.pop(ctx);
                    },
                  ),
                  if (current != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Tx('Tonic', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 16),
                          DropdownButton<int>(
                            value:
                                tonicChoices(current.divisions)
                                    .contains(state.tonicPos)
                                ? state.tonicPos
                                : defaultTonic(current.divisions),
                            dropdownColor: Palette.panel,
                            items: [
                              for (final p in tonicChoices(current.divisions))
                                DropdownMenuItem(
                                  value: p,
                                  child: Tx(
                                    tonicName(
                                      current.divisions,
                                      p,
                                      state.naming,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) state.setTonic(v);
                            },
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in builtInMaqams)
                          ListTile(
                            leading: Icon(
                              (m.pro && !state.isPro)
                                  ? Icons.lock_outline
                                  : Icons.timeline,
                            ),
                            title: Tx(m.name),
                            subtitle: Tx(m.systemLabel),
                            selected: state.maqamId == m.id,
                            trailing: (m.pro && !state.isPro)
                                ? const Tx(
                                    'Pro',
                                    style: TextStyle(color: Palette.brass),
                                  )
                                : null,
                            onTap: () {
                              if (m.pro && !state.isPro) {
                                Navigator.pop(ctx);
                                _openPaywall(context);
                              } else {
                                state.setMaqam(m.id);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SystemSelector extends StatelessWidget {
  const _SystemSelector({required this.state, required this.enabled});
  final AppState state;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final s in TuningSystem.all)
              ButtonSegment(value: s.divisions, label: Tx('${s.label}-TET')),
          ],
          selected: {state.system.divisions},
          onSelectionChanged: (v) =>
              state.setSystem(TuningSystem.byDivisions(v.first)),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Palette.panel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Palette.brass.withAlpha(120)),
    ),
    child: Tx(text, style: const TextStyle(fontSize: 14)),
  );
}
