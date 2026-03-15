import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A [CustomPaint] widget that renders a circular SOC (State of Charge) gauge.
///
/// The arc sweeps from 225° to 315° (270° total) clockwise, coloured:
///   ≤ 20 % → red   |  ≤ 50 % → amber   |  > 50 % → teal/green
class SocGauge extends StatelessWidget {
  const SocGauge({
    super.key,
    required this.soc,
    this.size = 220,
  });

  /// State of charge value in the range [0, 100].
  final double soc;

  /// Diameter of the gauge widget.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SocGaugePainter(soc: soc.clamp(0, 100)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${soc.toStringAsFixed(1)} %',
                style: TextStyle(
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'SOC',
                style: TextStyle(
                  fontSize: size * 0.08,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocGaugePainter extends CustomPainter {
  const _SocGaugePainter({required this.soc});

  final double soc;

  // The gauge arc spans 270° starting at 135° (7 o'clock position).
  static const double _startAngle = 135 * (math.pi / 180);
  static const double _totalSweep = 270 * (math.pi / 180);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    final strokeWidth = size.width * 0.08;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final trackPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    // Foreground arc (actual SOC)
    final sweepAngle = _totalSweep * (soc / 100.0);
    final fgPaint = Paint()
      ..color = _colorForSoc(soc)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, sweepAngle, false, fgPaint);
  }

  static Color _colorForSoc(double soc) {
    if (soc <= 20) return const Color(0xFFE63946);  // red
    if (soc <= 50) return const Color(0xFFFFB703);  // amber
    return const Color(0xFF2EC4B6);                 // teal
  }

  @override
  bool shouldRepaint(covariant _SocGaugePainter old) => old.soc != soc;
}
