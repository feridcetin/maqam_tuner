import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/maqam.dart';
import '../core/tuning_system.dart';
import '../l10n/l10n.dart';
import '../l10n/tx.dart';
import 'theme.dart';

/// Reference tone generator: pick any step of the chosen system and hear it,
/// or play the currently selected scale up and down.
class TonePage extends StatefulWidget {
  const TonePage({super.key, required this.state});
  final AppState state;

  @override
  State<TonePage> createState() => _TonePageState();
}

class _TonePageState extends State<TonePage> {
  int _step = 0; // relative to A4 in the current system
  int _lastDivisions = 12;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _lastDivisions = s.system.divisions;
    s.addListener(_onState);
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (s.system.divisions != _lastDivisions) {
      _lastDivisions = s.system.divisions;
      _step = 0;
      s.tones.stop();
    }
  }

  Future<void> _move(int delta) async {
    final limit = s.system.divisions * 3;
    setState(() => _step = (_step + delta).clamp(-limit, limit));
    if (s.tones.droning) await s.tones.drone(s.system.hzForStep(_step, s.a4));
  }

  Future<void> _toggleDrone() async {
    if (s.tones.droning) {
      await s.tones.stop();
    } else {
      await s.tones.drone(s.system.hzForStep(_step, s.a4));
    }
  }

  Future<void> _toggleScale(Maqam m) async {
    if (s.tones.scaleRunning) {
      await s.tones.stop();
      return;
    }
    final up = scaleSteps(m, s.tonicPos);
    final seq = [...up, ...up.reversed.skip(1)];
    final sys = TuningSystem.byDivisions(m.divisions);
    await s.tones.playScale([for (final st in seq) sys.hzForStep(st, s.a4)]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([s, s.tones]),
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final pad = width < 360 ? 14.0 : 20.0;
        final sys = s.system;
        final p = sys.describeStep(_step, a4: s.a4, naming: s.naming);
        final hz = sys.hzForStep(_step, s.a4);
        final maqam = s.maqam;
        final droning = s.tones.droning;
        final scaleRunning = s.tones.scaleRunning;
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              Tx(
                'Reference tone',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${sys.label}-TET · ${L10n.i.t(sys.description)}',
                style: const TextStyle(color: Palette.muted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 108,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '${p.octave}',
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
                height: 28,
                child: Center(
                  child: Text(
                    p.detail ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, color: Palette.brass),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${hz.toStringAsFixed(2)} Hz',
                  style: const TextStyle(color: Palette.muted, fontSize: 16),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _stepButton(
                      'Octave −',
                      Icons.keyboard_double_arrow_left,
                      () => _move(-sys.divisions),
                    ),
                  ),
                  Expanded(
                    child: _stepButton(
                      'Step −',
                      Icons.chevron_left,
                      () => _move(-1),
                    ),
                  ),
                  Expanded(
                    child: _stepButton(
                      'Step +',
                      Icons.chevron_right,
                      () => _move(1),
                    ),
                  ),
                  Expanded(
                    child: _stepButton(
                      'Octave +',
                      Icons.keyboard_double_arrow_right,
                      () => _move(sys.divisions),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _toggleDrone,
                icon: Icon(droning ? Icons.stop : Icons.volume_up),
                label: Tx(droning ? 'Stop tone' : 'Play steady tone'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => s.tones.pluck(hz),
                icon: const Icon(Icons.graphic_eq),
                label: const Tx('Play plucked note'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Tx(
                'Scale',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              if (maqam == null)
                const Tx(
                  'Choose a scale with the "Scale" chip on the Tuner tab, then come back to hear it '
                  'played up and down. Singing or playing along with it trains your ear for quarter tones.',
                  style: TextStyle(color: Palette.muted, fontSize: 13),
                )
              else ...[
                Text(
                  L10n.i.fmt('{0} on {1} · {2}', [
                    maqam.name,
                    tonicName(maqam.divisions, s.tonicPos, s.naming),
                    maqam.systemLabel,
                  ]),
                  style: const TextStyle(color: Palette.brass),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => _toggleScale(maqam),
                  icon: Icon(scaleRunning ? Icons.stop : Icons.play_arrow),
                  label: Tx(
                    scaleRunning ? 'Stop scale' : 'Play scale up and down',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Tx(
                'Tip: hold the steady tone while you tune by ear, and compare it with your string. '
                'Change the tuning system on the Tuner tab.',
                style: TextStyle(color: Palette.muted, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stepButton(String label, IconData icon, VoidCallback onTap) => Column(
    children: [
      IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Tx(
          label,
          style: const TextStyle(fontSize: 11, color: Palette.muted),
        ),
      ),
    ],
  );
}
