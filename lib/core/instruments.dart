import 'dart:math';

import 'tuning_system.dart';

class StringTarget {
  const StringTarget(this.label, this.semitonesFromA4);
  final String label;
  final double semitonesFromA4;

  double hz(double a4) => a4 * pow(2, semitonesFromA4 / 12);
}

class Instrument {
  const Instrument(this.id, this.name, this.strings, {this.pro = false});
  final String id;
  final String name;
  final List<StringTarget> strings;
  final bool pro;

  static Instrument fromNotes(
    String id,
    String name,
    List<String> notes, {
    bool pro = false,
  }) {
    final list = <StringTarget>[];
    for (final n in notes) {
      final s = noteToSemitones(n);
      if (s != null) list.add(StringTarget(n, s));
    }
    return Instrument(id, name, list, pro: pro);
  }
}

/// Oud tunings are the common ones documented by oud makers and players;
/// Arabic: C F A D G C (most common), D G A D G C. Turkish: C# F# B E A D, E A B E A D.
final List<Instrument> builtInInstruments = [
  Instrument.fromNotes('oud_ar', 'Oud · Arabic', [
    'C2',
    'F2',
    'A2',
    'D3',
    'G3',
    'C4',
  ]),
  Instrument.fromNotes('oud_ar_d', 'Oud · Arabic (D)', [
    'D2',
    'G2',
    'A2',
    'D3',
    'G3',
    'C4',
  ]),
  Instrument.fromNotes('oud_tr', 'Oud · Turkish', [
    'C#2',
    'F#2',
    'B2',
    'E3',
    'A3',
    'D4',
  ]),
  Instrument.fromNotes('oud_tr_e', 'Oud · Turkish (E)', [
    'E2',
    'A2',
    'B2',
    'E3',
    'A3',
    'D4',
  ]),
  Instrument.fromNotes('guitar', 'Guitar', [
    'E2',
    'A2',
    'D3',
    'G3',
    'B3',
    'E4',
  ]),
  Instrument.fromNotes('violin', 'Violin', ['G3', 'D4', 'A4', 'E5']),
  Instrument.fromNotes('ukulele', 'Ukulele', [
    'G4',
    'C4',
    'E4',
    'A4',
  ], pro: true),
  Instrument.fromNotes('bass', 'Bass guitar', [
    'E1',
    'A1',
    'D2',
    'G2',
  ], pro: true),
  Instrument.fromNotes('mandolin', 'Mandolin', [
    'G3',
    'D4',
    'A4',
    'E5',
  ], pro: true),
  Instrument.fromNotes('cello', 'Cello', ['C2', 'G2', 'D3', 'A3'], pro: true),
];

/// Returns the nearest string and the deviation in cents.
({StringTarget target, double cents})? nearestString(
  Instrument inst,
  double hz,
  double a4,
) {
  if (inst.strings.isEmpty) return null;
  StringTarget? best;
  var bestCents = double.infinity;
  for (final s in inst.strings) {
    final c = 1200 * log(hz / s.hz(a4)) / ln2;
    if (c.abs() < bestCents.abs()) {
      bestCents = c;
      best = s;
    }
  }
  return (target: best!, cents: bestCents);
}

/// Cents from [hz] to a given string.
double centsTo(StringTarget t, double hz, double a4) =>
    1200 * log(hz / t.hz(a4)) / ln2;
