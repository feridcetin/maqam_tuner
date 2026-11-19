import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'tone_synth.dart';

/// Plays synthesized reference tones. No audio assets are needed.
/// Notifies listeners when the drone or scale starts or stops, so every
/// screen shows the true state (a tab switch used to leave a stale
/// "Stop tone" button).
class ToneService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  bool droning = false;
  bool scaleRunning = false;
  int _epoch = 0;

  Future<void> _pluckRaw(double hz) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.release);
    await _player.play(BytesSource(synthPluck(hz), mimeType: 'audio/wav'));
  }

  /// One plucked note (also cancels a running drone or scale).
  Future<void> pluck(double hz) async {
    _epoch++;
    droning = false;
    scaleRunning = false;
    notifyListeners();
    await _pluckRaw(hz);
  }

  Future<void> drone(double hz) async {
    _epoch++;
    scaleRunning = false;
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(BytesSource(synthDrone(hz), mimeType: 'audio/wav'));
    droning = true;
    notifyListeners();
  }

  /// Plays the notes one after another until finished or [stop] is called.
  Future<void> playScale(
    List<double> hzList, {
    Duration gap = const Duration(milliseconds: 750),
  }) async {
    final mine = ++_epoch;
    droning = false;
    scaleRunning = true;
    notifyListeners();
    for (final hz in hzList) {
      if (mine != _epoch) return;
      await _pluckRaw(hz);
      await Future<void>.delayed(gap);
    }
    if (mine == _epoch) {
      scaleRunning = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _epoch++;
    droning = false;
    scaleRunning = false;
    await _player.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
