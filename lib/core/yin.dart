import 'dart:typed_data';

class YinResult {
  const YinResult(this.hz, this.clarity);
  final double hz;

  /// 0..1, higher is a cleaner periodic signal.
  final double clarity;
}

/// YIN fundamental-frequency estimator (de Cheveigné & Kawahara, 2002).
/// Pure Dart, no dependencies.
YinResult? yinDetect(
  Float64List x,
  double sampleRate, {
  double minHz = 50,
  double maxHz = 1500,
  double threshold = 0.15,
}) {
  final n = x.length;
  final tauMin = (sampleRate / maxHz).floor().clamp(2, n ~/ 2);
  var tauMax = (sampleRate / minHz).ceil();
  if (tauMax > n ~/ 2) tauMax = n ~/ 2;
  if (tauMax <= tauMin + 2) return null;
  final w = n - tauMax;

  final cm = Float64List(tauMax + 1);
  cm[0] = 1;
  var running = 0.0;
  for (var tau = 1; tau <= tauMax; tau++) {
    var sum = 0.0;
    for (var j = 0; j < w; j++) {
      final d = x[j] - x[j + tau];
      sum += d * d;
    }
    running += sum;
    cm[tau] = running == 0 ? 1 : sum * tau / running;
  }

  int? best;
  for (var t = tauMin; t < tauMax; t++) {
    if (cm[t] < threshold) {
      while (t + 1 < tauMax && cm[t + 1] < cm[t]) {
        t++;
      }
      best = t;
      break;
    }
  }
  if (best == null) {
    var minIdx = tauMin;
    for (var t = tauMin; t < tauMax; t++) {
      if (cm[t] < cm[minIdx]) minIdx = t;
    }
    if (cm[minIdx] < 0.3) best = minIdx;
  }
  if (best == null) return null;

  var tauEst = best.toDouble();
  if (best > 1 && best < tauMax) {
    final s0 = cm[best - 1], s1 = cm[best], s2 = cm[best + 1];
    final denom = 2 * (2 * s1 - s2 - s0);
    if (denom != 0) tauEst += (s2 - s0) / denom;
  }
  final clarity = (1 - cm[best]).clamp(0.0, 1.0);
  return YinResult(sampleRate / tauEst, clarity);
}
