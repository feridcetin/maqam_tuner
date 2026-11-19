import 'dart:math';
import 'dart:typed_data';

import 'package:maqam_tuner/audio/tone_synth.dart';
import 'package:maqam_tuner/core/yin.dart';

Float64List decode(Uint8List wav, int from, int count) {
  final bd = ByteData.sublistView(wav);
  final out = Float64List(count);
  for (var i = 0; i < count; i++) {
    out[i] = bd.getInt16(44 + (from + i) * 2, Endian.little) / 32768.0;
  }
  return out;
}

void check(bool ok, String msg) {
  print('${ok ? "PASS" : "FAIL"}  $msg');
  if (!ok) throw Exception(msg);
}

void main() {
  for (final f in [65.41, 110.0, 220.0, 440.0, 523.25]) {
    final d = synthDrone(f);
    final bd = ByteData.sublistView(d);
    check(
      String.fromCharCodes(d.sublist(0, 4)) == 'RIFF' &&
          bd.getUint16(20, Endian.little) == 1,
      'WAV header ok ($f)',
    );
    final x = decode(d, 0, min(4410, (d.length - 44) ~/ 2));
    final r = yinDetect(x, 44100.0, minHz: 50, maxHz: 1500);
    final err = r == null ? 999 : (1200 * log(r.hz / f) / ln2).abs();
    check(
      err < 0.5,
      'drone $f Hz decoded -> ${r?.hz.toStringAsFixed(3)} (${err.toStringAsFixed(3)} cents)',
    );
  }
  final p = synthPluck(110.0);
  final x = decode(p, 2000, 4410);
  final r = yinDetect(x, 44100.0);
  check(
    r != null && (1200 * log(r.hz / 110.0) / ln2).abs() < 1,
    'pluck 110 Hz -> ${r?.hz.toStringAsFixed(2)}',
  );
  check(p.length == 44 + 44100 * 3 * 2, 'pluck length 3 s');
}
