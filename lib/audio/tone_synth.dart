import 'dart:math';
import 'dart:typed_data';

const int _sr = 44100;

/// Plucked-string style tone (decaying harmonics), ~3 s. One-shot.
Uint8List synthPluck(double hz, {double seconds = 3.0}) {
  final n = (_sr * seconds).round();
  final out = Float64List(n);
  const amps = [1.0, 0.55, 0.35, 0.22, 0.14, 0.09, 0.05];
  const nyquist = _sr / 2;
  for (var h = 0; h < amps.length; h++) {
    final f = hz * (h + 1);
    if (f >= nyquist) break;
    final decay = 1.6 + h * 1.3; // higher harmonics fade faster
    final w = 2 * pi * f / _sr;
    for (var i = 0; i < n; i++) {
      out[i] += amps[h] * sin(w * i) * exp(-decay * i / _sr);
    }
  }
  return _toWav(out, attackMs: 4, releaseMs: 30);
}

/// Seamless looping drone. The loop length is a whole number of cycles so the
/// pitch stays exact and there is no click at the loop point.
Uint8List synthDrone(double hz) {
  final cycles = max(1, hz.round());
  final n = (_sr * cycles / hz).round();
  final actualHz = _sr * cycles / n;
  final out = Float64List(n);
  const amps = [1.0, 0.28, 0.12];
  for (var h = 0; h < amps.length; h++) {
    final f = actualHz * (h + 1);
    if (f >= _sr / 2) break;
    final w = 2 * pi * f / _sr;
    for (var i = 0; i < n; i++) {
      out[i] += amps[h] * sin(w * i);
    }
  }
  return _toWav(out, attackMs: 0, releaseMs: 0);
}

Uint8List _toWav(
  Float64List samples, {
  required int attackMs,
  required int releaseMs,
}) {
  var peak = 0.0;
  for (final v in samples) {
    if (v.abs() > peak) peak = v.abs();
  }
  final gain = peak == 0 ? 0.0 : 0.8 / peak;
  final n = samples.length;
  final a = (_sr * attackMs / 1000).round();
  final r = (_sr * releaseMs / 1000).round();
  final data = ByteData(44 + n * 2);
  void ascii(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _sr, Endian.little);
  data.setUint32(28, _sr * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    var v = samples[i] * gain;
    if (a > 0 && i < a) v *= i / a;
    if (r > 0 && i > n - r) v *= (n - i) / r;
    data.setInt16(
      44 + i * 2,
      (v.clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
