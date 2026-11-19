import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/pitch_pipeline.dart';

/// Listens to the microphone and publishes a stable pitch estimate.
/// The signal processing lives in [PitchPipeline] (pure Dart, unit tested).
///
/// Reliability features (competitor apps are criticised for freezing needles
/// and going silent after app switches):
///  * a watchdog restarts the microphone if audio stops arriving,
///  * [suspend]/[resume] pause and restore listening across tab or app switches,
///  * detection is muted while the app plays a reference tone itself,
///  * the screen stays on while listening.
class TunerController extends ChangeNotifier {
  final AudioRecorder _rec = AudioRecorder();
  final PitchPipeline _pipe = PitchPipeline();
  StreamSubscription<Uint8List>? _sub;
  Timer? _watchdog;
  DateTime _lastChunk = DateTime.now();
  DateTime _mutedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _starting = false;

  /// 0 = noisy room, 1 = normal, 2 = quiet room / weak sound.
  int get sensitivity => _pipe.sensitivity;
  set sensitivity(int v) => _pipe.sensitivity = v;

  double? get hz => _pipe.hz;
  double get level => _pipe.level;

  /// The user wants the tuner on (even if it is temporarily suspended).
  bool wanted = false;
  bool listening = false;
  bool permissionDenied = false;
  String? error;

  /// Ignore the microphone for a while, e.g. while a reference tone plays,
  /// so the tuner does not "tune" the app's own speaker output.
  void muteFor(Duration d) {
    _mutedUntil = DateTime.now().add(d);
    _pipe.reset();
    notifyListeners();
  }

  /// User pressed Start.
  Future<void> start() async {
    wanted = true;
    await _open();
  }

  /// User pressed Stop.
  Future<void> stop() async {
    wanted = false;
    await _close();
  }

  /// Temporarily release the microphone (tab change, app in background).
  Future<void> suspend() => _close();

  /// Restore listening if the user had it on.
  Future<void> resume() async {
    if (wanted && !listening) await _open();
  }

  Future<void> _open() async {
    if (listening || _starting) return;
    _starting = true;
    error = null;
    permissionDenied = false;
    try {
      if (!await _rec.hasPermission()) {
        permissionDenied = true;
        wanted = false;
        notifyListeners();
        return;
      }
      final stream = await _rec.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: PitchPipeline.inRate,
          numChannels: 1,
          // Phone voice processing distorts instrument tones: switch it all off.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.mic,
          ),
        ),
      );
      _pipe.reset();
      _lastChunk = DateTime.now();
      listening = true;
      _sub = stream.listen(
        _onData,
        onError: (Object e) {
          error = 'Microphone error: $e';
          _restart();
        },
      );
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        if (listening &&
            DateTime.now().difference(_lastChunk).inMilliseconds > 2000) {
          _restart();
        }
      });
      WakelockPlus.enable();
    } catch (e) {
      error = 'Could not start the microphone: $e';
      listening = false;
    } finally {
      _starting = false;
    }
    notifyListeners();
  }

  Future<void> _close() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _rec.stop();
    } catch (_) {}
    WakelockPlus.disable();
    listening = false;
    _pipe.reset();
    notifyListeners();
  }

  Future<void> _restart() async {
    await _close();
    if (wanted) await _open();
  }

  void _onData(Uint8List bytes) {
    final now = DateTime.now();
    _lastChunk = now; // keeps the watchdog happy even while muted
    if (now.isBefore(_mutedUntil)) return;
    final bd = ByteData.sublistView(bytes);
    final samples = List<double>.generate(
      bytes.length ~/ 2,
      (i) => bd.getInt16(i * 2, Endian.little) / 32768.0,
    );
    if (_pipe.add(samples, now.millisecondsSinceEpoch)) notifyListeners();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _sub?.cancel();
    _rec.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
