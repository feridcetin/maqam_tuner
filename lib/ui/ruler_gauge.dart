import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'theme.dart';

/// A horizontal ruler: the centre is the target pitch, the ends are
/// +/- [half] cents. Ticks are drawn like a luthier's fret ruler.
class RulerGauge extends StatelessWidget {
  const RulerGauge({
    super.key,
    required this.cents,
    required this.half,
    required this.tolerance,
  });

  /// null = no signal (needle hidden).
  final double? cents;
  final double half;
  final double tolerance;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: cents ?? 0),
      duration: const Duration(milliseconds: 140),
      builder: (context, value, _) => SizedBox(
        height: 96,
        width: double.infinity,
        child: CustomPaint(
          painter: _RulerPainter(
            cents: cents == null ? null : value,
            half: half,
            tolerance: tolerance,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.cents,
    required this.half,
    required this.tolerance,
  });
  final double? cents;
  final double half;
  final double tolerance;
  final String lang = L10n.i.code;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final usable = size.width / 2 - 14;
    final base = size.height * 0.5;

    // in-tune zone
    final zone = Rect.fromCenter(
      center: Offset(cx, base),
      width: usable * 2 * (tolerance / half),
      height: 44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(zone, const Radius.circular(8)),
      Paint()..color = Palette.ok.withAlpha(36),
    );

    // ticks
    final tick = Paint()
      ..color = Palette.muted
      ..strokeCap = StrokeCap.round;
    for (var i = -10; i <= 10; i++) {
      final x = cx + usable * i / 10;
      final major = i % 5 == 0;
      final h = i == 0 ? 36.0 : (major ? 28.0 : 14.0);
      tick.strokeWidth = i == 0 ? 3 : (major ? 2 : 1.2);
      tick.color = i == 0 ? Palette.brass : Palette.muted;
      canvas.drawLine(Offset(x, base - h / 2), Offset(x, base + h / 2), tick);
    }

    _label(canvas, L10n.i.t('flat'), Offset(cx - usable, base + 34));
    _label(canvas, L10n.i.t('sharp'), Offset(cx + usable, base + 34));

    final c = cents;
    if (c != null) {
      final inTune = c.abs() <= tolerance;
      final color = inTune ? Palette.ok : Palette.ivory;
      final x = cx + usable * (c / half).clamp(-1.08, 1.08);
      final p = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, base - 30), Offset(x, base + 30), p);
      final tri = Path()
        ..moveTo(x - 7, base - 38)
        ..lineTo(x + 7, base - 38)
        ..lineTo(x, base - 28)
        ..close();
      canvas.drawPath(tri, Paint()..color = color);
    }
  }

  void _label(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Palette.muted, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.cents != cents ||
      old.half != half ||
      old.tolerance != tolerance ||
      old.lang != lang;
}
