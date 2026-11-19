import 'dart:math';

import 'tuning_system.dart';

/// A scale ("maqam" / "makam") defined by its step pattern in an equal division
/// of the octave. These are the usual theoretical/teaching values; real
/// performance practice varies between players and regions.
class Maqam {
  const Maqam(
    this.id,
    this.name,
    this.divisions,
    this.intervals, {
    this.pro = false,
  });
  final String id;
  final String name;
  final int divisions; // 12, 24 or 53
  final List<int> intervals; // steps between degrees, sums to [divisions]
  final bool pro;

  /// Cumulative positions of the degrees above the tonic (tonic = 0).
  List<int> get degrees {
    final out = <int>[];
    var acc = 0;
    for (final i in intervals) {
      out.add(acc);
      acc += i;
    }
    return out;
  }

  String get systemLabel => '$divisions-TET';
}

const List<Maqam> builtInMaqams = [
  // 24-TET (Arabic quarter tones)
  Maqam('rast24', 'Rast', 24, [4, 3, 3, 4, 4, 3, 3]),
  Maqam('bayati24', 'Bayati', 24, [3, 3, 4, 4, 2, 4, 4]),
  Maqam('hijaz24', 'Hijaz', 24, [2, 6, 2, 4, 2, 4, 4]),
  Maqam('saba24', 'Saba', 24, [3, 3, 2, 6, 2, 4, 4], pro: true),
  Maqam('sikah24', 'Sikah', 24, [3, 4, 4, 3, 3, 4, 3], pro: true),
  Maqam('nahawand24', 'Nahawand', 24, [4, 2, 4, 4, 2, 6, 2], pro: true),
  Maqam('kurd24', 'Kurd', 24, [2, 4, 4, 4, 2, 4, 4], pro: true),
  Maqam('ajam24', 'Ajam', 24, [4, 4, 2, 4, 4, 4, 2], pro: true),
  // 53-TET (Turkish koma)
  Maqam('rast53', 'Rast (53)', 53, [9, 8, 5, 9, 9, 8, 5]),
  Maqam('ussak53', 'Uşşak (53)', 53, [8, 5, 9, 9, 4, 9, 9]),
  Maqam('hicaz53', 'Hicaz (53)', 53, [5, 12, 5, 9, 4, 9, 9], pro: true),
  Maqam('kurdi53', 'Kürdi (53)', 53, [4, 9, 9, 9, 4, 9, 9], pro: true),
  // 12-TET
  Maqam('major12', 'Major', 12, [2, 2, 1, 2, 2, 2, 1]),
  Maqam('minor12', 'Natural minor', 12, [2, 1, 2, 2, 1, 2, 2], pro: true),
];

Maqam? maqamById(String id) {
  for (final m in builtInMaqams) {
    if (m.id == id) return m;
  }
  return null;
}

/// Allowed tonic positions (steps above A, 0..divisions-1).
List<int> tonicChoices(int divisions) {
  switch (divisions) {
    case 53:
      return const [0, 9, 13, 22, 31, 35, 44]; // A B C D E F G
    case 24:
      return List.generate(24, (i) => i);
    default:
      return List.generate(12, (i) => i);
  }
}

/// Default tonic: C in every system.
int defaultTonic(int divisions) => switch (divisions) {
  53 => 13,
  24 => 6,
  _ => 3,
};

class ScaleReading {
  const ScaleReading(this.degreeIndex, this.step, this.cents, this.targetHz);
  final int degreeIndex; // 0 = tonic
  final int step; // absolute step relative to A4
  final double cents; // negative = flat of the scale degree
  final double targetHz;
}

/// Finds the scale degree (in any octave) nearest to [hz].
ScaleReading nearestDegree(Maqam m, int tonicPos, double hz, double a4) {
  final div = m.divisions;
  final exact = div * (log(hz / a4) / ln2);
  final degs = m.degrees;
  final baseOct = (exact / div).floor();
  var bestIdx = 0;
  var bestStep = 0;
  var bestDist = double.infinity;
  for (var o = baseOct - 1; o <= baseOct + 1; o++) {
    for (var i = 0; i < degs.length; i++) {
      final s = tonicPos + degs[i] + div * o;
      final d = (exact - s).abs();
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
        bestStep = s;
      }
    }
  }
  final cents = (exact - bestStep) * 1200 / div;
  return ScaleReading(bestIdx, bestStep, cents, a4 * pow(2, bestStep / div));
}

/// Absolute steps (relative to A4) of one octave of the scale including the
/// upper tonic, starting at the tonic nearest below A4.
List<int> scaleSteps(Maqam m, int tonicPos) {
  final start = tonicPos - m.divisions;
  return [for (final d in m.degrees) start + d, start + m.divisions];
}

String tonicName(int divisions, int pos, NoteNaming naming) =>
    TuningSystem.byDivisions(divisions).describeStep(pos, naming: naming).name;
