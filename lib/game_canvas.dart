import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final Map<String, ui.Image?> avatarImages;

  GamePainter(this.engine, this.avatarImages);

  @override
  void paint(Canvas canvas, Size size) {
    if (!engine.isInited) return;
    _drawBackground(canvas, size);
    _drawSpinners(canvas);
    _drawFloatingTexts(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A0A1A), Color(0xFF0D1B2A), Color(0xFF1A0D2E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

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
      _drawSpinnerBody(canvas, s);   // berputar
      _drawAvatar(canvas, s);        // tidak berputar
      _drawHPBar(canvas, s);
      _drawLabel(canvas, s);
    }
  }

  // Bagian gasing yang BERPUTAR
  void _drawSpinnerBody(Canvas canvas, Spinner s) {
    canvas.save();
    canvas.translate(s.x, s.y);
    canvas.rotate(s.angle);

    // Shadow
    canvas.drawCircle(
      const Offset(3, 3), s.size,
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Body
    canvas.drawCircle(
      Offset.zero, s.size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            s.color.withOpacity(0.85),
            s.color.withOpacity(0.5),
            s.color.withOpacity(0.15),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s.size)),
    );

    // Sirip (3 sirip berputar)
    final finPaint = Paint()
      ..color = s.color.withOpacity(0.9)
      ..strokeWidth = s.size * 0.28
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final fa = i * pi * 2 / 3;
      canvas.drawLine(
        Offset(cos(fa) * s.size * 0.4, sin(fa) * s.size * 0.4),
        Offset(cos(fa) * s.size * 1.0, sin(fa) * s.size * 1.0),
        finPaint,
      );
    }

    // Ring luar
    canvas.drawCircle(
      Offset.zero, s.size * 0.95,
      Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  // Foto profil / inisial — TIDAK berputar
  void _drawAvatar(Canvas canvas, Spinner s) {
    // avatarR selalu ikut s.size — membesar/mengecil dinamis
    final avatarR = s.size * 0.60;
    final center = Offset(s.x, s.y);
    final img = avatarImages[s.username];

    if (img != null) {
      canvas.save();
      // Clip lingkaran sesuai ukuran gasing saat ini
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: avatarR)));
      // drawImageRect selalu scale foto ke avatarR yang dinamis
      final dst = Rect.fromCircle(center: center, radius: avatarR);
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.low);
      canvas.restore();

      // Border foto
      canvas.drawCircle(
        center, avatarR,
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    } else {
      // Fallback: titik putih + kilap
      canvas.drawCircle(center, s.size * 0.18, Paint()..color = Colors.white.withOpacity(0.9));
      canvas.drawCircle(
        Offset(s.x - s.size * 0.25, s.y - s.size * 0.25),
        s.size * 0.12,
        Paint()..color = Colors.white.withOpacity(0.5),
      );
    }
  }

  void _drawDeadSpinner(Canvas canvas, Spinner s) {
    final opacity = (s.deadTimer / 90.0).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(s.x, s.y);

    canvas.drawCircle(
      Offset.zero, s.size * opacity,
      Paint()
        ..color = Colors.grey.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

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
    const barH = 5.0;
    final bx = s.x - barW / 2;
    final by = s.y + s.size + 6;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barW, barH), const Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    final ratio = (s.hp / s.maxHp).clamp(0.0, 1.0);
    if (ratio > 0) {
      final hpColor = ratio > 0.5
          ? Color.lerp(Colors.yellow, Colors.green, (ratio - 0.5) * 2)!
          : Color.lerp(Colors.red, Colors.yellow, ratio * 2)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barW * ratio, barH), const Radius.circular(3)),
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
          shadows: [Shadow(color: Colors.black.withOpacity(0.9), offset: const Offset(1, 1), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(s.x - tp.width / 2, s.y + s.size + 14));
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
            shadows: [Shadow(color: Colors.black.withOpacity(opacity), offset: const Offset(1, 1), blurRadius: 3)],
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
