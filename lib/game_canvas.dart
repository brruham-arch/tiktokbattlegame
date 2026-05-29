import 'package:flutter/material.dart';
import 'models.dart';
import 'game_engine.dart';
import 'pixel_painter.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;

  GamePainter(this.engine);

  @override
  void paint(Canvas canvas, Size size) {
    if (!engine.isInited) return;
    _drawBackground(canvas, size);
    _drawGround(canvas, size);
    _drawPlayers(canvas);
    _drawFloatingTexts(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D0D2B), Color(0xFF1A1A4E), Color(0xFF2D1B69)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.8);
    for (int i = 0; i < 40; i++) {
      final x = (i * 137.5 + 50) % size.width;
      final y = (i * 97.3 + 20) % (engine.groundY * 0.7);
      final blink = (engine.tick ~/ 30 + i) % 3 == 0;
      canvas.drawRect(Rect.fromLTWH(x, y, blink ? 2 : 1, blink ? 2 : 1), starPaint);
    }

    // Moon
    canvas.drawRect(Rect.fromLTWH(size.width - 60, 20, 16, 16),
      Paint()..color = const Color(0xFFFFF9C4));
    canvas.drawRect(Rect.fromLTWH(size.width - 56, 24, 8, 8),
      Paint()..color = const Color(0xFF1A1A4E));

    _drawBuildings(canvas, size);
  }

  void _drawBuildings(Canvas canvas, Size size) {
    final buildPaint = Paint()..color = const Color(0xFF1C1C3A);
    final windowPaint = Paint()..color = const Color(0xFFFFEB3B).withOpacity(0.6);

    final buildings = [
      [20.0, 40.0, 40.0],
      [80.0, 60.0, 30.0],
      [130.0, 80.0, 50.0],
      [200.0, 50.0, 35.0],
      [size.width - 100, 70.0, 45.0],
      [size.width - 160, 55.0, 30.0],
      [size.width - 220, 90.0, 60.0],
    ];

    for (final b in buildings) {
      final bx = b[0]; final bh = b[1]; final bw = b[2];
      final by = engine.groundY - bh;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, bh), buildPaint);
      for (int wy = 0; wy < (bh / 12).floor(); wy++) {
        for (int wx = 0; wx < (bw / 12).floor(); wx++) {
          if ((wy + wx + bx.toInt()) % 3 != 0) {
            canvas.drawRect(
              Rect.fromLTWH(bx + 4 + wx * 12, by + 4 + wy * 12, 6, 6),
              windowPaint);
          }
        }
      }
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    final s = engine.scale;
    final cols = [const Color(0xFF4CAF50), const Color(0xFF388E3C)];
    final dirt = const Color(0xFF795548);
    final count = (size.width / s).ceil() + 1;

    for (int i = 0; i < count; i++) {
      canvas.drawRect(Rect.fromLTWH(i * s, engine.groundY, s, s),
        Paint()..color = cols[i % 2]);
    }
    for (int row = 1; row < 4; row++) {
      for (int i = 0; i < count; i++) {
        canvas.drawRect(Rect.fromLTWH(i * s, engine.groundY + row * s, s, s),
          Paint()..color = dirt);
      }
    }
    canvas.drawLine(Offset(0, engine.groundY), Offset(size.width, engine.groundY),
      Paint()..color = Colors.black..strokeWidth = 1);
  }

  void _drawPlayers(Canvas canvas) {
    for (final player in engine.players) {
      PixelPainter.drawPlayer(canvas, player, engine.scale);
      PixelPainter.drawHPBar(canvas, player, engine.scale);
      PixelPainter.drawUsername(canvas, player, engine.scale);
    }
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
      tp.paint(canvas, Offset(ft.x, ft.y));
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
