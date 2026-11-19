import 'dart:math';
import 'dart:typed_data';

import 'package:maqam_tuner/core/tuning_system.dart';
import 'package:maqam_tuner/core/yin.dart';
import 'package:maqam_tuner/core/instruments.dart';
import 'package:maqam_tuner/core/maqam.dart';

void check(bool ok, String msg) {
  print('${ok ? "PASS" : "FAIL"}  $msg');
  if (!ok) throw Exception(msg);
}

void main() {
  maqamTests();
  var p = TuningSystem.edo12.analyze(440);
  check(p.name == 'A' && p.octave == 4 && p.cents.abs() < 1e-6, '12-TET A4');
  p = TuningSystem.edo12.analyze(261.6256);
  check(p.name == 'C' && p.octave == 4, '12-TET C4 -> ${p.name}${p.octave}');
  p = TuningSystem.edo12.analyze(65.4064);
  check(p.name == 'C' && p.octave == 2, '12-TET C2 -> ${p.name}${p.octave}');
  p = TuningSystem.edo12.analyze(440 * pow(2, 0.2 / 12).toDouble());
  check(
    (p.cents - 20).abs() < 0.01,
    '+20 cents -> ${p.cents.toStringAsFixed(2)}',
  );

  p = TuningSystem.edo24.describeStep(1);
  check(p.name == 'A+', '24-TET step1 -> ${p.name}');
  p = TuningSystem.edo24.describeStep(3);
  check(
    p.name == 'B−' && p.octave == 4,
    '24-TET step3 -> ${p.name}${p.octave}',
  );
  p = TuningSystem.edo24.describeStep(-1);
  check(p.name == 'G#+' || p.name == 'A−', '24-TET step-1 -> ${p.name}');
  p = TuningSystem.edo24.describeStep(7);
  check(p.octave == 5, '24-TET step7 octave -> ${p.name}${p.octave}');

  p = TuningSystem.edo53.describeStep(0);
  check(p.name == 'A' && p.octave == 4 && p.detail == null, '53-TET A4');
  p = TuningSystem.edo53.describeStep(9);
  check(p.name == 'B' && p.octave == 4, '53-TET B4 -> ${p.name}${p.octave}');
  p = TuningSystem.edo53.describeStep(13);
  check(p.name == 'C' && p.octave == 5, '53-TET C5 -> ${p.name}${p.octave}');
  p = TuningSystem.edo53.describeStep(-40);
  check(p.name == 'C' && p.octave == 4, '53-TET C4 -> ${p.name}${p.octave}');
  p = TuningSystem.edo53.describeStep(4);
  check(
    p.name == 'A' && p.detail == '+4 koma · bakiye',
    '53-TET +4 -> ${p.name} ${p.detail}',
  );
  p = TuningSystem.edo53.describeStep(-5);
  check(
    p.name == 'G' && p.octave == 4 && p.detail == '+4 koma · bakiye',
    '53-TET -5 -> ${p.name}${p.octave} ${p.detail}',
  );
  p = TuningSystem.edo53.describeStep(5);
  check(
    p.name == 'B' && p.detail == '−4 koma · bakiye',
    '53-TET +5 -> ${p.name} ${p.detail}',
  );
  p = TuningSystem.edo53.describeStep(53);
  check(p.name == 'A' && p.octave == 5, '53-TET A5 -> ${p.name}${p.octave}');
  p = TuningSystem.edo53.describeStep(51);
  check(
    p.name == 'A' && p.octave == 5 && p.detail == '−2 koma',
    '53-TET step51 -> ${p.name}${p.octave} ${p.detail}',
  );

  check(
    noteToSemitones('A4') == 0 &&
        noteToSemitones('C2') == -33 &&
        noteToSemitones('Bb3') == -11,
    'note parser',
  );
  check(noteToSemitones('H9') == null, 'note parser rejects junk');

  const sr = 22050.0;
  final rnd = Random(1);
  double worst = 0;
  for (final f in [
    65.41,
    82.41,
    110.0,
    146.83,
    196.0,
    261.63,
    329.63,
    440.0,
    659.26,
    987.77,
  ]) {
    final x = Float64List(2560);
    for (var i = 0; i < x.length; i++) {
      final t = i / sr;
      var v =
          0.35 * sin(2 * pi * f * t) +
          0.6 * sin(2 * pi * 2 * f * t) +
          0.4 * sin(2 * pi * 3 * f * t) +
          0.2 * sin(2 * pi * 4 * f * t);
      v += (rnd.nextDouble() - 0.5) * 0.1;
      x[i] = v;
    }
    final r = yinDetect(x, sr, minHz: 35);
    final err = r == null ? 9999.0 : (1200 * log(r.hz / f) / ln2).abs();
    worst = max(worst, err);
    check(
      r != null && err < 3,
      'YIN ${f}Hz -> ${r?.hz.toStringAsFixed(2)} (${err.toStringAsFixed(2)} cents, clarity ${r?.clarity.toStringAsFixed(2)})',
    );
  }
  final noise = Float64List(2560);
  for (var i = 0; i < noise.length; i++) {
    noise[i] = (rnd.nextDouble() - 0.5);
  }
  final rn = yinDetect(noise, sr);
  check(
    rn == null || rn.clarity < 0.8,
    'noise rejected/low clarity (${rn?.clarity})',
  );

  final oud = builtInInstruments.first;
  final n = nearestString(oud, 111.0, 440)!;
  check(
    n.target.label == 'A2' && n.cents > 0,
    'nearest string 111Hz -> ${n.target.label} ${n.cents.toStringAsFixed(1)}c',
  );
  print('worst YIN error: ${worst.toStringAsFixed(2)} cents');
}

void maqamTests() {
  for (final m in builtInMaqams) {
    check(
      m.intervals.fold<int>(0, (a, b) => a + b) == m.divisions,
      'maqam ${m.id} intervals sum to ${m.divisions}',
    );
  }
  // Rast on C in 24-TET: degree 3 is E half-flat = 7 quarter steps above C
  final rast = maqamById('rast24')!;
  check(
    rast.degrees.join(',') == '0,4,7,10,14,18,21',
    'Rast degrees ${rast.degrees}',
  );
  // C4 = 261.6256 Hz -> tonic, then E half-flat (C4 + 350 cents)
  var r = nearestDegree(rast, defaultTonic(24), 261.6256, 440);
  check(
    r.degreeIndex == 0 && r.cents.abs() < 0.1,
    'tonic C4 -> degree ${r.degreeIndex} ${r.cents.toStringAsFixed(2)}c',
  );
  final eHalfFlat = 261.6256 * pow(2, 350 / 1200).toDouble();
  r = nearestDegree(
    rast,
    defaultTonic(24),
    eHalfFlat * pow(2, 10 / 1200).toDouble(),
    440,
  );
  check(
    r.degreeIndex == 2 && (r.cents - 10).abs() < 0.2,
    'E half-flat +10c -> degree ${r.degreeIndex} ${r.cents.toStringAsFixed(2)}c',
  );
  final nm = TuningSystem.edo24.describeStep(r.step);
  check(nm.name == 'E−', 'degree 3 of Rast on C is named ${nm.name}');
  // octave independence
  r = nearestDegree(rast, defaultTonic(24), 261.6256 * 4, 440);
  check(r.degreeIndex == 0 && r.cents.abs() < 0.1, 'tonic two octaves up');
  r = nearestDegree(rast, defaultTonic(24), 130.8128, 440);
  check(r.degreeIndex == 0 && r.cents.abs() < 0.1, 'tonic one octave down');
  // Turkish Rast on G (44): Dügah (A, +9 above G) must be degree 2
  final rast53 = maqamById('rast53')!;
  final g4 = 440 * pow(2, -9 / 53).toDouble();
  final a4 = 440.0;
  r = nearestDegree(rast53, 44, a4, 440);
  check(
    r.degreeIndex == 1 && r.cents.abs() < 0.1,
    '53 Rast on G: A is degree ${r.degreeIndex + 1}',
  );
  r = nearestDegree(rast53, 44, g4, 440);
  check(r.degreeIndex == 0 && r.cents.abs() < 0.1, '53 Rast on G: tonic');
  check(
    scaleSteps(rast, 6).length == 8 && scaleSteps(rast, 6).last == 6,
    'scaleSteps incl. upper tonic',
  );
  check(
    tonicChoices(53).length == 7 && tonicChoices(24).length == 24,
    'tonic choices',
  );

  // quarter-tone note parser
  check(
    noteToSemitones('Bd3') == noteToSemitones('Bb3')! + 0.5,
    'Bd3 is half-flat',
  );
  check(
    noteToSemitones('Bs3') == noteToSemitones('B3')! + 0.5,
    'Bs3 half-sharp',
  );
  check(noteToSemitones('Bb3') == -11, 'Bb3 still flat');
}
