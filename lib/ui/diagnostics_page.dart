import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../app_state.dart';
import '../core/pitch_pipeline.dart';
import '../l10n/l10n.dart';
import '../l10n/tx.dart';
import 'theme.dart';

/// "Phone check": lets the user judge the app WITHOUT a real instrument.
///  1. Detection test: synthetic notes straight into the detection code
///     (no microphone, no speaker) -> proves the algorithm and CPU speed.
///  2. Microphone check: real sample rate and background noise of this phone.
///  3. Speaker-to-microphone: plays 440 Hz and listens to it.
/// If step 1 passes and step 2 shows ~44100 Hz, a wrong reading in the tuner
/// comes from the room, the speaker or the source, not from the app.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.state});
  final AppState state;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  final AudioRecorder _recorder = AudioRecorder();
  String? _r1;
  String? _r2;
  String? _r3;
  bool _busy = false;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  List<double> _synth(double f, double seconds) {
    final rnd = Random(1);
    final n = (44100 * seconds).round();
    return List.generate(n, (i) {
      final t = i / 44100;
      final v =
          sin(2 * pi * f * t) +
          0.5 * sin(2 * pi * 2 * f * t) +
          0.3 * sin(2 * pi * 3 * f * t) +
          0.15 * sin(2 * pi * 4 * f * t);
      return 0.25 * v + (rnd.nextDouble() - 0.5) * 0.02;
    });
  }

  Future<void> _detectionTest() async {
    setState(() {
      _busy = true;
      _r1 = L10n.i.t('Running…');
    });
    const freqs = [
      41.2, 65.41, 82.41, 110.0, 146.83, 196.0,
      261.63, 329.63, 440.0, 523.25, 659.26, 880.0, //
    ];
    var passed = 0;
    var worst = 0.0;
    var frames = 0;
    final sw = Stopwatch();
    for (final f in freqs) {
      final pipe = PitchPipeline();
      final x = _synth(f, 1.5);
      sw.start();
      var t = 0;
      for (var i = 0; i + 1764 <= x.length; i += 1764) {
        t += 40;
        pipe.add(x.sublist(i, i + 1764), t);
      }
      sw.stop();
      frames += pipe.frames;
      final hz = pipe.hz;
      final err = hz == null ? 999.0 : (1200 * log(hz / f) / ln2).abs();
      if (err < 3) passed++;
      worst = max(worst, err);
      await Future<void>.delayed(Duration.zero); // keep the UI alive
    }
    final ms = frames == 0 ? 0.0 : sw.elapsedMicroseconds / 1000 / frames;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _r1 = L10n.i.fmt(
        'Passed {0} of {1} notes · worst error {2} cents · about {3} ms per analysis',
        [
          passed,
          freqs.length,
          worst >= 999 ? '—' : worst.toStringAsFixed(1),
          ms.toStringAsFixed(1),
        ],
      );
    });
  }

  /// Records for [d]; returns (samples per second, RMS) or null without permission.
  Future<({double rate, double rms})?> _capture(
    Duration d, {
    void Function(List<double> samples, int nowMs)? onSamples,
  }) async {
    if (!await _recorder.hasPermission()) return null;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: PitchPipeline.inRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
      ),
    );
    final clock = Stopwatch()..start();
    var total = 0;
    var firstLen = 0;
    var sq = 0.0;
    int? tFirst;
    var tLast = 0;
    final sub = stream.listen((bytes) {
      final bd = ByteData.sublistView(bytes);
      final list = List<double>.generate(
        bytes.length ~/ 2,
        (i) => bd.getInt16(i * 2, Endian.little) / 32768.0,
      );
      for (final v in list) {
        sq += v * v;
      }
      total += list.length;
      final now = clock.elapsedMicroseconds;
      if (tFirst == null) {
        tFirst = now;
        firstLen = list.length;
      }
      tLast = now;
      onSamples?.call(list, DateTime.now().millisecondsSinceEpoch);
    });
    await Future<void>.delayed(d);
    await sub.cancel();
    await _recorder.stop();
    final span = (tLast - (tFirst ?? tLast)) / 1e6;
    final rate = span > 0 ? (total - firstLen) / span : 0.0;
    return (rate: rate, rms: total == 0 ? 0.0 : sqrt(sq / total));
  }

  Future<void> _micCheck() async {
    setState(() {
      _busy = true;
      _r2 = L10n.i.t('Running…');
    });
    final cap = await _capture(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (cap == null) {
        _r2 = L10n.i.t('Microphone permission is off.');
      } else {
        final db = cap.rms <= 0 ? -120.0 : 20 * log(cap.rms) / ln10;
        final verdict = db < -45
            ? 'Quiet enough for tuning.'
            : 'Noisy. Use the Noisy room setting or move somewhere quieter.';
        _r2 =
            '${L10n.i.fmt('Sample rate {0} Hz (should be about 44100)', [cap.rate.round()])}\n'
            '${L10n.i.fmt('Background noise {0} dB', [db.round()])}\n'
            '${L10n.i.t(verdict)}';
      }
    });
  }

  Future<void> _loopback() async {
    setState(() {
      _busy = true;
      _r3 = L10n.i.t('Running…');
    });
    final pipe = PitchPipeline(sensitivity: 2);
    await widget.state.tones.drone(440);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final cap = await _capture(
      const Duration(milliseconds: 2500),
      onSamples: (s, now) => pipe.add(s, now),
    );
    await widget.state.tones.stop();
    if (!mounted) return;
    setState(() {
      _busy = false;
      final hz = pipe.hz;
      if (cap == null) {
        _r3 = L10n.i.t('Microphone permission is off.');
      } else if (hz == null) {
        _r3 = L10n.i.t(
          'Nothing clear was heard. Raise the volume and try again.',
        );
      } else {
        final cents = 1200 * log(hz / 440) / ln2;
        _r3 = L10n.i.fmt('Heard {0} Hz · {1} cents from 440', [
          hz.toStringAsFixed(1),
          '${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)}',
        ]);
      }
    });
  }

  Future<void> _copy() async {
    final report = [
      'Maqam Tuner phone check',
      '1) ${_r1 ?? '-'}',
      '2) ${_r2?.replaceAll('\n', ' | ') ?? '-'}',
      '3) ${_r3 ?? '-'}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Tx('Report copied.')));
  }

  Widget _step(
    String title,
    String body,
    String button,
    VoidCallback run,
    String? result,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Tx(body, style: const TextStyle(color: Palette.muted, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy ? null : run,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: Tx(button),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            SelectableText(result, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < 360 ? 14.0 : 20.0;
    return Scaffold(
      appBar: AppBar(title: const Tx('Phone check')),
      body: ListenableBuilder(
        listenable: L10n.i,
        builder: (context, _) => ListView(
          padding: EdgeInsets.all(pad),
          children: [
            const Tx(
              'Checks the app on your phone. No instrument needed.',
              style: TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 16),
            _step(
              'Step 1 · Detection test',
              'Runs 12 synthetic notes through the same detection code. No microphone or speaker is involved, so it checks the app itself.',
              'Run detection test',
              _detectionTest,
              _r1,
            ),
            _step(
              'Step 2 · Microphone check',
              'Stay quiet for 3 seconds. This measures background noise and the real sample rate your microphone delivers.',
              'Run microphone check',
              _micCheck,
              _r2,
            ),
            _step(
              'Step 3 · Speaker to microphone test',
              'Plays 440 Hz from this phone and listens to it. Turn the volume up and keep the phone still.',
              'Run loopback test',
              _loopback,
              _r3,
            ),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy),
              label: const Tx('Copy report'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
