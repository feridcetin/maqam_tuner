import 'dart:math';

enum NoteNaming { letters, solfege }

int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q;
}

int _mod(int a, int b) => ((a % b) + b) % b;

const _letters = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];
const _solfege = [
  'Do',
  'Do#',
  'Re',
  'Re#',
  'Mi',
  'Fa',
  'Fa#',
  'Sol',
  'Sol#',
  'La',
  'La#',
  'Si',
];

/// 53-TET natural notes: comma position counted upward from A -> semitone index (C=0).
const _naturals53 = <int, int>{0: 9, 9: 11, 13: 0, 22: 2, 31: 4, 35: 5, 44: 7};

const _accidentalNames53 = <int, String>{
  4: 'bakiye',
  5: 'küçük mücenneb',
  8: 'büyük mücenneb',
};

class PitchInfo {
  const PitchInfo({
    required this.name,
    required this.octave,
    required this.step,
    required this.cents,
    required this.stepCents,
    required this.targetHz,
    this.detail,
  });

  /// e.g. "A", "E−", "C#"
  final String name;
  final int octave;

  /// Step index relative to A4 in the chosen system.
  final int step;

  /// Deviation from the nearest step, in cents (negative = flat).
  final double cents;
  final double stepCents;
  final double targetHz;

  /// Extra line, e.g. "+4 koma · bakiye" in 53-TET.
  final String? detail;
}

class TuningSystem {
  const TuningSystem._(this.divisions, this.label, this.description);

  static const edo12 = TuningSystem._(12, '12', 'Western equal temperament');
  static const edo24 = TuningSystem._(24, '24', 'Arabic quarter-tones (maqam)');
  static const edo53 = TuningSystem._(53, '53', 'Turkish makam (koma)');
  static const all = [edo12, edo24, edo53];

  static TuningSystem byDivisions(int n) =>
      all.firstWhere((s) => s.divisions == n, orElse: () => edo12);

  final int divisions;
  final String label;
  final String description;

  double get stepCents => 1200.0 / divisions;

  double hzForStep(int step, double a4) => a4 * pow(2, step / divisions);

  PitchInfo analyze(
    double hz, {
    double a4 = 440.0,
    NoteNaming naming = NoteNaming.letters,

    /// Step shown in the previous frame. A pitch that sits near the boundary
    /// of two steps (a quarter tone in 12-TET) keeps the old step until it is
    /// clearly closer to the neighbour, so the note name does not flicker.
    int? stickyStep,
  }) {
    final exact = divisions * (log(hz / a4) / ln2);
    var step = exact.round();
    if (stickyStep != null && (exact - stickyStep).abs() < 0.6) {
      step = stickyStep;
    }
    final cents = (exact - step) * stepCents;
    final target = hzForStep(step, a4);
    final names = naming == NoteNaming.letters ? _letters : _solfege;

    switch (divisions) {
      case 12:
        final abs = 9 + step;
        return PitchInfo(
          name: names[_mod(abs, 12)],
          octave: 4 + _floorDiv(abs, 12),
          step: step,
          cents: cents,
          stepCents: stepCents,
          targetHz: target,
        );
      case 24:
        final lowerSemi = 9 + _floorDiv(step, 2);
        String name;
        int absSemi;
        if (step.isEven) {
          absSemi = lowerSemi;
          name = names[_mod(absSemi, 12)];
        } else {
          final upper = lowerSemi + 1;
          final upperName = names[_mod(upper, 12)];
          if (!upperName.contains('#')) {
            absSemi = upper;
            name = '$upperName−'; // quarter-flat
          } else {
            absSemi = lowerSemi;
            name = '${names[_mod(lowerSemi, 12)]}+'; // quarter-sharp
          }
        }
        return PitchInfo(
          name: name,
          octave: 4 + _floorDiv(absSemi, 12),
          step: step,
          cents: cents,
          stepCents: stepCents,
          targetHz: target,
        );
      default: // 53
        final pos = _mod(step, 53);
        var bestKey = 0;
        var bestOffset = 99;
        for (final k in [..._naturals53.keys, 53]) {
          final off = pos - k;
          if (off.abs() < bestOffset.abs()) {
            bestOffset = off;
            bestKey = k;
          }
        }
        final naturalSemi = _naturals53[bestKey == 53 ? 0 : bestKey]!;
        final naturalStep = step - bestOffset;
        final octave = 4 + _floorDiv(naturalStep - 13, 53) + 1;
        String? detail;
        if (bestOffset != 0) {
          final n = bestOffset.abs();
          final sign = bestOffset > 0 ? '+' : '−';
          final extra = _accidentalNames53[n];
          detail = extra == null ? '$sign$n koma' : '$sign$n koma · $extra';
        }
        return PitchInfo(
          name: names[naturalSemi],
          octave: octave,
          step: step,
          cents: cents,
          stepCents: stepCents,
          targetHz: target,
          detail: detail,
        );
    }
  }

  /// Name of an arbitrary step, used by the tone generator.
  PitchInfo describeStep(
    int step, {
    double a4 = 440.0,
    NoteNaming naming = NoteNaming.letters,
  }) => analyze(hzForStep(step, a4), a4: a4, naming: naming);
}

/// Parses "C#2", "Bb3", "a4" -> semitones relative to A4. Returns null if invalid.
/// Quarter-tone accidentals: "d" = half-flat (koron), "s" = half-sharp (sori),
/// e.g. "Bd3" is B half-flat in octave 3.
double? noteToSemitones(String text) {
  final m = RegExp(r'^([A-Ga-g])(#|b|d|s)?(-?\d)$').firstMatch(text.trim());
  if (m == null) return null;
  const base = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  var semi = base[m.group(1)!.toUpperCase()]!.toDouble();
  switch (m.group(2)) {
    case '#':
      semi += 1;
    case 'b':
      semi -= 1;
    case 'd':
      semi -= 0.5;
    case 's':
      semi += 0.5;
  }
  final octave = int.parse(m.group(3)!);
  return (octave - 4) * 12 + semi - 9;
}
