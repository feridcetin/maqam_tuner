import 'dart:typed_data';
import 'dart:math';

import 'yin.dart';

/// The whole detection chain in one pure-Dart class so it can be unit-tested
/// and also run by the in-app "Phone check" without a microphone.
///
/// 44.1 kHz samples -> decimate to 22.05 kHz -> YIN every ~60 ms ->
/// reject quiet / unclear frames -> median of the last frames, shown only when
/// the last three agree. Showing nothing beats showing a wrong number.
class PitchPipeline {
  PitchPipeline({this.sensitivity = 1});

  static const inRate = 44100;
  static const outRate = 22050.0;
  static const win = 2560; // decimated samples analysed per frame
  static const minHz = 35.0; // bass guitar low E is 41 Hz
  static const frameMs = 60;

  /// 0 = noisy room, 1 = normal, 2 = quiet room / weak sound.
  int sensitivity;
  double get rmsGate => const [0.012, 0.004, 0.0015][sensitivity.clamp(0, 2)];
  double get minClarity => const [0.92, 0.85, 0.80][sensitivity.clamp(0, 2)];

  final List<double> _buf = [];
  final List<double> _recent = [];
  int _lastRunMs = -1000000;
  int _lastHitMs = -1000000;

  /// Stable pitch to display, or null.
  double? hz;

  /// Smoothed signal level (RMS, 0..1).
  double level = 0;

  /// Number of frames analysed so far.
  int frames = 0;

  void reset() {
    _buf.clear();
    _recent.clear();
    _lastRunMs = -1000000;
    _lastHitMs = -1000000;
    hz = null;
    level = 0;
  }

  /// Feed 44.1 kHz mono samples (-1..1). [nowMs] is the time of the newest
  /// sample (wall clock in the app, sample clock in tests). Returns true when
  /// a frame was analysed (state may have changed).
  bool add(List<double> samples, int nowMs) {
    _buf.addAll(samples);
    const keep = 2 * win + 1024;
    if (_buf.length > keep) _buf.removeRange(0, _buf.length - keep);
    if (nowMs - _lastRunMs < frameMs) return false;
    final start = _buf.length - 2 * win;
    if (start < 1) return false;
    _lastRunMs = nowMs;
    frames++;

    final x = Float64List(win);
    var sq = 0.0;
    for (var i = 0; i < win; i++) {
      final j = start + 2 * i;
      final v = 0.25 * _buf[j - 1] + 0.5 * _buf[j] + 0.25 * _buf[j + 1];
      x[i] = v;
      sq += v * v;
    }
    final rms = sqrt(sq / win);
    level = level * 0.6 + rms * 0.4;

    YinResult? r;
    if (rms >= rmsGate) r = yinDetect(x, outRate, minHz: minHz);
    if (r != null && r.clarity >= minClarity) {
      _lastHitMs = nowMs;
      _recent.add(r.hz);
      if (_recent.length > 5) _recent.removeAt(0);
      if (_recent.length >= 3) {
        final last3 = _recent.sublist(_recent.length - 3);
        final spread = 1200 * log(last3.reduce(max) / last3.reduce(min)) / ln2;
        if (spread < 60) {
          final sorted = [..._recent]..sort();
          hz = sorted[sorted.length ~/ 2];
        }
      }
    } else if (nowMs - _lastHitMs > 500) {
      hz = null;
      _recent.clear();
    }
    return true;
  }
}
