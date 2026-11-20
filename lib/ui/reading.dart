import 'dart:math';

import '../app_state.dart';
import '../core/instruments.dart';
import '../core/maqam.dart';
import '../core/tuning_system.dart';
import '../l10n/l10n.dart';

/// What the tuner screen shows for one detected frequency.
class Reading {
  const Reading({
    required this.note,
    required this.cents,
    required this.half,
    required this.hz,
    required this.targetHz,
    this.octave,
    this.detail,
    this.stringLabel,
    this.step,
  });

  final String note;
  final String? octave;
  final String? detail;
  final double cents;

  /// Ruler half-range in cents.
  final double half;
  final double hz;
  final double targetHz;
  final String? stringLabel;

  /// Chromatic mode only: the step shown, fed back as the sticky step.
  final int? step;

  double get tolerance => min(5.0, half * 0.25);
  bool get inTune => cents.abs() <= tolerance;
}

Reading? computeReading(AppState s, double? hz, {int? stickyStep}) {
  if (hz == null) return null;
  final inst = s.instrument;
  final maqam = s.maqam;

  if (inst != null) {
    StringTarget? target;
    final locked = s.lockedString;
    if (locked != null) {
      for (final t in inst.strings) {
        if (t.label == locked) target = t;
      }
    }
    target ??= nearestString(inst, hz, s.a4)?.target;
    if (target == null) return null;
    final label = target.label;
    return Reading(
      note: label.replaceAll(RegExp(r'-?\d$'), ''),
      octave: RegExp(r'-?\d$').firstMatch(label)?.group(0),
      cents: centsTo(target, hz, s.a4),
      half: 50,
      hz: hz,
      targetHz: target.hz(s.a4),
      stringLabel: label,
      detail: locked != null
          ? L10n.i.fmt('Locked to {0} · tap the string again to unlock', [
              label,
            ])
          : null,
    );
  }

  if (maqam != null) {
    final r = nearestDegree(maqam, s.tonicPos, hz, s.a4);
    final sys = TuningSystem.byDivisions(maqam.divisions);
    final p = sys.describeStep(r.step, a4: s.a4, naming: s.naming);
    final parts = <String>[
      if (p.detail != null) p.detail!,
      L10n.i.fmt('degree {0} of {1}', [
        r.degreeIndex + 1,
        L10n.i.t(maqam.name),
      ]),
    ];
    return Reading(
      note: p.name,
      octave: '${p.octave}',
      detail: parts.join(' · '),
      cents: r.cents,
      half: 40,
      hz: hz,
      targetHz: r.targetHz,
    );
  }

  final p = s.system.analyze(
    hz,
    a4: s.a4,
    naming: s.naming,
    stickyStep: stickyStep,
  );
  return Reading(
    note: p.name,
    octave: '${p.octave}',
    detail: p.detail,
    cents: p.cents,
    half: p.stepCents / 2,
    hz: hz,
    targetHz: p.targetHz,
    step: p.step,
  );
}
