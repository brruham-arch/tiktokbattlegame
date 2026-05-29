import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;

  GamePainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    if (!engine.isInited) return;
    _drawBackground(canvas, size);
    _drawSpinners(canvas);
    _drawFloatingTexts(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Background gradien gelap
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A0A1A), Color(0xFF0D1B2A), Color(0xFF1A0D2E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid pattern
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Border arena
    final borderPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      borderPaint,
    );
  }

  void _drawSpinners(Canvas canvas) {
    for (final s in engine.spinners) {
      if (!s.isAlive) {
        _drawDeadSpinner(canvas, s);
        continue;
      }
      _drawSpinner(canvas, s);
      _drawHPBar(canvas, s);
      _drawLabel(canvas, s);
    }
  }

  void _drawSpinner(Canvas canvas, Spinner s) {
    canvas.save();
    canvas.translate(s.x, s.y);
    canvas.rotate(s.angle);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(3, 3), s.size, shadowPaint);

    // Body utama gasing
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          s.color.withOpacity(0.95),
          s.color.withOpacity(0.6),
          s.color.withOpacity(0.3),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: s.size));
    canvas.drawCircle(Offset.zero, s.size, bodyPaint);

    // Sirip gasing (3 sirip berputar)
    final finPaint = Paint()
      ..color = s.color.withOpacity(0.85)
      ..strokeWidth = s.size * 0.28
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final finAngle = (i * pi * 2 / 3);
      final x1 = cos(finAngle) * s.size * 0.4;
      final y1 = sin(finAngle) * s.size * 0.4;
      final x2 = cos(finAngle) * s.size * 1.0;
      final y2 = sin(finAngle) * s.size * 1.0;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), finPaint);
    }

    // Lingkaran luar (ring)
    final ringPaint = Paint()
      ..color = s.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, s.size * 0.95, ringPaint);

    // Titik tengah
    canvas.drawCircle(
      Offset.zero, s.size * 0.18,
      Paint()..color = Colors.white.withOpacity(0.9),
    );

    // Kilap
    canvas.drawCircle(
      Offset(-s.size * 0.25, -s.size * 0.25),
      s.size * 0.12,
      Paint()..color = Colors.white.withOpacity(0.5),
    );

    canvas.restore();
  }

  void _drawDeadSpinner(Canvas canvas, Spinner s) {
    final opacity = (s.deadTimer / 90.0).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(s.x, s.y);

    final deadPaint = Paint()
      ..color = Colors.grey.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, s.size * opacity, deadPaint);

    // X mark
    final xPaint = Paint()
      ..color = Colors.red.withOpacity(opacity * 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final r = s.size * 0.5 * opacity;
    canvas.drawLine(Offset(-r, -r), Offset(r, r), xPaint);
    canvas.drawLine(Offset(r, -r), Offset(-r, r), xPaint);

    canvas.restore();
  }

  void _drawHPBar(Canvas canvas, Spinner s) {
    final barW = s.size * 2.2;
    final barH = 5.0;
    final bx = s.x - barW / 2;
    final by = s.y + s.size + 6;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, barW, barH),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    // HP fill
    final ratio = (s.hp / s.maxHp).clamp(0.0, 1.0);
    final hpColor = ratio > 0.5
        ? Color.lerp(Colors.yellow, Colors.green, (ratio - 0.5) * 2)!
        : Color.lerp(Colors.red, Colors.yellow, ratio * 2)!;
    if (ratio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, barW * ratio, barH),
          const Radius.circular(3),
        ),
        Paint()..color = hpColor,
      );
    }
  }

  void _drawLabel(Canvas canvas, Spinner s) {
    final tp = TextPainter(
      text: TextSpan(
        text: s.displayName,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: (s.size * 0.38).clamp(9.0, 14.0),
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.9),
              offset: const Offset(1, 1), blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(s.x - tp.width / 2, s.y - tp.height / 2));
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final ft in engine.floatingTexts) {
      final opacity = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(opacity),
            fontSize: ft.size,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            shadows: [Shadow(
              color: Colors.black.withOpacity(opacity),
              offset: const Offset(1, 1), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(ft.x - tp.width / 2, ft.y));
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
