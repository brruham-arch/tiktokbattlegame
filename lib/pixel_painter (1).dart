import 'package:flutter/material.dart';
import 'models.dart';

// 8x8 pixel sprite definitions
// Each list is rows top-to-bottom, each int is a row of 8 pixels (bit = 1 means draw)
class PixelSprites {
  // Body pixel map: 1=body, 2=skin, 3=hair, 4=eye, 0=transparent
  static const List<List<int>> idleFrame1 = [
    [0, 0, 3, 3, 3, 3, 0, 0], // hair
    [0, 3, 2, 2, 2, 2, 3, 0], // head top
    [0, 2, 2, 4, 2, 4, 2, 0], // eyes
    [0, 2, 2, 2, 2, 2, 2, 0], // face
    [0, 1, 1, 1, 1, 1, 1, 0], // shoulders
    [1, 0, 1, 1, 1, 1, 0, 1], // arms
    [0, 0, 1, 1, 1, 1, 0, 0], // body lower
    [0, 0, 1, 0, 0, 1, 0, 0], // legs
  ];

  static const List<List<int>> idleFrame2 = [
    [0, 0, 3, 3, 3, 3, 0, 0],
    [0, 3, 2, 2, 2, 2, 3, 0],
    [0, 2, 2, 4, 2, 4, 2, 0],
    [0, 2, 2, 2, 2, 2, 2, 0],
    [0, 1, 1, 1, 1, 1, 1, 0],
    [0, 1, 1, 1, 1, 1, 1, 0], // arms down
    [0, 0, 1, 1, 1, 1, 0, 0],
    [0, 0, 1, 0, 0, 1, 0, 0],
  ];

  static const List<List<int>> attackFrame = [
    [0, 0, 3, 3, 3, 3, 0, 0],
    [0, 3, 2, 2, 2, 2, 3, 0],
    [0, 2, 2, 4, 2, 4, 2, 0],
    [0, 2, 2, 2, 3, 2, 2, 0], // angry mouth
    [0, 1, 1, 1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 0, 0, 0], // punch arm extended
    [0, 0, 1, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 1, 0, 0, 0], // legs spread
  ];

  static const List<List<int>> hurtFrame = [
    [0, 0, 3, 3, 3, 3, 0, 0],
    [0, 3, 2, 2, 2, 2, 3, 0],
    [0, 2, 4, 2, 2, 4, 2, 0], // x eyes
    [0, 2, 2, 3, 2, 2, 2, 0],
    [0, 0, 1, 1, 1, 1, 0, 0],
    [0, 1, 0, 1, 1, 0, 1, 0],
    [0, 0, 1, 0, 0, 1, 0, 0],
    [0, 1, 0, 0, 0, 0, 1, 0], // knocked
  ];

  static const List<List<int>> deadFrame = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [3, 3, 3, 3, 2, 2, 2, 2],
    [2, 2, 4, 2, 2, 4, 2, 2],
    [1, 1, 1, 1, 1, 1, 1, 1],
    [0, 1, 0, 1, 1, 0, 1, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
  ];

  static List<List<int>> getFrame(PlayerState state, int animFrame) {
    switch (state) {
      case PlayerState.attack:
        return attackFrame;
      case PlayerState.hurt:
        return hurtFrame;
      case PlayerState.dead:
        return deadFrame;
      case PlayerState.celebrate:
        return animFrame % 2 == 0 ? idleFrame1 : idleFrame2;
      default:
        return animFrame % 2 == 0 ? idleFrame1 : idleFrame2;
    }
  }
}

class PixelPainter {
  static void drawPlayer(
    Canvas canvas,
    Player player,
    double scale,
  ) {
    final frame = PixelSprites.getFrame(player.state, player.animFrame);
    final pixelSize = scale;

    final bodyColor = player.color;
    final skinColor = const Color(0xFFFFD5A8);
    final hairColor = HSLColor.fromColor(player.color)
        .withLightness(0.3)
        .toColor();
    final eyeColor = Colors.black;

    // Flash white when hurt
    final isHurtFlash = player.state == PlayerState.hurt && player.animFrame % 2 == 0;

    for (int row = 0; row < frame.length; row++) {
      for (int col = 0; col < frame[row].length; col++) {
        final pixel = frame[row][col];
        if (pixel == 0) continue;

        Color color;
        switch (pixel) {
          case 1:
            color = isHurtFlash ? Colors.white : bodyColor;
            break;
          case 2:
            color = isHurtFlash ? Colors.white : skinColor;
            break;
          case 3:
            color = isHurtFlash ? Colors.white : hairColor;
            break;
          case 4:
            color = isHurtFlash ? Colors.red : eyeColor;
            break;
          default:
            color = bodyColor;
        }

        final drawCol = player.facingRight ? col : (7 - col);
        final rect = Rect.fromLTWH(
          player.x + drawCol * pixelSize,
          player.y + row * pixelSize,
          pixelSize,
          pixelSize,
        );

        canvas.drawRect(rect, Paint()..color = color);

        // Pixel outline
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    // Draw shadow
    if (player.state != PlayerState.dead) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            player.x + 4 * pixelSize,
            player.y + 8 * pixelSize,
          ),
          width: 6 * pixelSize,
          height: 2 * pixelSize,
        ),
        shadowPaint,
      );
    }
  }

  static void drawHPBar(Canvas canvas, Player player, double scale) {
    final barWidth = 8 * scale;
    final barHeight = scale * 1.5;
    final barX = player.x;
    final barY = player.y - barHeight - 2;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth, barHeight),
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    // HP fill
    final hpRatio = player.hp / player.maxHp;
    final hpColor = hpRatio > 0.5
        ? Colors.greenAccent
        : hpRatio > 0.25
            ? Colors.orangeAccent
            : Colors.redAccent;

    if (hpRatio > 0) {
      canvas.drawRect(
        Rect.fromLTWH(barX, barY, barWidth * hpRatio, barHeight),
        Paint()..color = hpColor,
      );
    }

    // Border
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth, barHeight),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  static void drawUsername(Canvas canvas, Player player, double scale) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: player.displayName,
        style: TextStyle(
          color: player.state == PlayerState.dead
              ? Colors.grey
              : Colors.white,
          fontSize: scale * 1.8,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        player.x + (8 * scale - textPainter.width) / 2,
        player.y - scale * 3.5,
      ),
    );
  }
}
