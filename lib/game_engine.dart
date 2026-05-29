import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

class GameEngine {
  final List<Spinner> spinners = [];
  final List<FloatingText> floatingTexts = [];
  final List<String> eventLog = [];
  final Random _rng = Random();

  double arenaW = 400;
  double arenaH = 700;
  int tick = 0;
  bool isInited = false;

  static const List<Color> spinnerColors = [
    Color(0xFF4FC3F7), Color(0xFFEF5350), Color(0xFF66BB6A),
    Color(0xFFFFCA28), Color(0xFFAB47BC), Color(0xFFFF7043),
    Color(0xFF26C6DA), Color(0xFFEC407A), Color(0xFF80CBC4),
    Color(0xFFFFCC02), Color(0xFF69F0AE), Color(0xFFFF6D00),
  ];

  void init(double w, double h) {
    arenaW = w;
    arenaH = h;
    isInited = true;
  }

  Color _nextColor() {
    final used = spinners.map((s) => s.color).toSet();
    for (final c in spinnerColors) {
      if (!used.contains(c)) return c;
    }
    return Color((0xFF000000 | _rng.nextInt(0xFFFFFF)));
  }

  Spinner? findSpinner(String username) {
    try {
      return spinners.firstWhere(
        (s) => s.username.toLowerCase() == username.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Spinner spawnSpinner(String username, {String? avatarPath}) {
    final existing = findSpinner(username);
    if (existing != null) {
      if (existing.isAlive) return existing;
      // Sudah mati — tidak langsung respawn, perlu like/komen
      return existing;
    }

    final margin = Spinner.maxSizeCap;
    final x = margin + _rng.nextDouble() * (arenaW - margin * 2);
    final y = margin + _rng.nextDouble() * (arenaH - margin * 2);
    final spd = Spinner.baseSpeed;
    final angle = _rng.nextDouble() * pi * 2;

    final s = Spinner(
      username: username,
      x: x, y: y,
      color: _nextColor(),
      vx: cos(angle) * spd,
      vy: sin(angle) * spd,
    );
    s.avatarPath = avatarPath;
    spinners.add(s);
    _spawnText('${s.displayName} joined! 🌀', x, y - 30, s.color, 12);
    addLog('🌀 ${s.displayName} masuk arena!');
    return s;
  }

  void handleLike(String username, int count) {
    final s = findSpinner(username);
    if (s == null) {
      // Belum pernah join, spawn dulu
      spawnSpinner(username);
      return;
    }
    if (!s.isAlive) {
      // Respawn via like
      final margin = Spinner.maxSizeCap;
      final rx = margin + _rng.nextDouble() * (arenaW - margin * 2);
      final ry = margin + _rng.nextDouble() * (arenaH - margin * 2);
      s.revive(rx, ry);
      _spawnText('REVIVED! ❤️', s.x, s.y - 30, Colors.pinkAccent, 14);
      addLog('💗 ${s.displayName} respawn via like!');
      return;
    }
    // +1 ukuran & +1 HP per like
    s.addSize(count * 0.3);
    _spawnText('+${count} ❤️', s.x, s.y - s.size - 10, Colors.pinkAccent, 12);
    addLog('❤️ ${s.displayName} +$count ukuran');
  }

  void handleComment(String username) {
    final s = findSpinner(username);
    if (s == null) {
      spawnSpinner(username);
      return;
    }
    if (!s.isAlive) {
      final margin = Spinner.maxSizeCap;
      final rx = margin + _rng.nextDouble() * (arenaW - margin * 2);
      final ry = margin + _rng.nextDouble() * (arenaH - margin * 2);
      s.revive(rx, ry);
      _spawnText('REVIVED! 💬', s.x, s.y - 30, Colors.cyanAccent, 14);
      addLog('💬 ${s.displayName} respawn via komen!');
      return;
    }
    // +10 ukuran & +10 HP per komentar
    s.addSize(10.0);
    _spawnText('+10 💬', s.x, s.y - s.size - 10, Colors.cyanAccent, 12);
  }

  void _checkCollisions() {
    for (int i = 0; i < spinners.length; i++) {
      for (int j = i + 1; j < spinners.length; j++) {
        final a = spinners[i];
        final b = spinners[j];
        if (!a.isAlive || !b.isAlive) continue;

        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = a.size + b.size;

        if (dist < minDist && dist > 0) {
          // Pisahkan overlap
          final nx = dx / dist;
          final ny = dy / dist;
          final overlap = minDist - dist;
          a.x -= nx * overlap * 0.5;
          a.y -= ny * overlap * 0.5;
          b.x += nx * overlap * 0.5;
          b.y += ny * overlap * 0.5;

          // Pantulan kecepatan
          final relVx = a.vx - b.vx;
          final relVy = a.vy - b.vy;
          final dot = relVx * nx + relVy * ny;
          if (dot > 0) {
            a.vx -= dot * nx;
            a.vy -= dot * ny;
            b.vx += dot * nx;
            b.vy += dot * ny;
          }

          // Damage = ukuran lawan, floor 5, tapi tidak terlalu signifikan untuk kecil
          final dmgToB = (a.size * 0.18).clamp(5.0, 25.0).round();
          final dmgToA = (b.size * 0.18).clamp(5.0, 25.0).round();

          a.takeDamage(dmgToA);
          b.takeDamage(dmgToB);

          _spawnText('-$dmgToB', b.x + dx * 0.3, b.y - b.size - 8, Colors.redAccent, 11);
          _spawnText('-$dmgToA', a.x - dx * 0.3, a.y - a.size - 8, Colors.redAccent, 11);

          if (!a.isAlive) {
            _spawnText('KO! 💀', a.x, a.y, Colors.red, 16);
            addLog('💀 ${b.displayName} KO ${a.displayName}!');
            b.score += 50;
          }
          if (!b.isAlive) {
            _spawnText('KO! 💀', b.x, b.y, Colors.red, 16);
            addLog('💀 ${a.displayName} KO ${b.displayName}!');
            a.score += 50;
          }
        }
      }
    }
  }

  void _spawnText(String text, double x, double y, Color color, double size) {
    floatingTexts.add(FloatingText(text: text, x: x, y: y, color: color, size: size));
  }

  void addLog(String msg) {
    eventLog.insert(0, msg);
    if (eventLog.length > 20) eventLog.removeLast();
  }

  void update() {
    if (!isInited) return;
    tick++;

    for (final s in spinners) {
      if (!s.isAlive) {
        if (s.deadTimer > 0) s.deadTimer--;
        if (s.deadTimer == 0) s.pendingRemoval = true;
        continue;
      }

      // Rotasi gasing
      s.angle += s.spinSpeed;

      // Gerak
      s.x += s.vx;
      s.y += s.vy;

      // Pantul dinding
      if (s.x - s.size < 0) {
        s.x = s.size;
        s.vx = s.vx.abs();
      }
      if (s.x + s.size > arenaW) {
        s.x = arenaW - s.size;
        s.vx = -s.vx.abs();
      }
      if (s.y - s.size < 0) {
        s.y = s.size;
        s.vy = s.vy.abs();
      }
      if (s.y + s.size > arenaH) {
        s.y = arenaH - s.size;
        s.vy = -s.vy.abs();
      }

      // Pastikan kecepatan sesuai size (fisika)
      final spd = s.speed;
      final currentSpd = sqrt(s.vx * s.vx + s.vy * s.vy);
      if (currentSpd > 0.1) {
        s.vx = (s.vx / currentSpd) * spd;
        s.vy = (s.vy / currentSpd) * spd;
      } else {
        // Kalau hampir berhenti, beri dorongan random
        final angle = _rng.nextDouble() * pi * 2;
        s.vx = cos(angle) * spd;
        s.vy = sin(angle) * spd;
      }
    }

    _checkCollisions();

    // Hapus yang sudah selesai mati
    spinners.removeWhere((s) => s.pendingRemoval);

    // Update floating texts
    floatingTexts.removeWhere((ft) => ft.life <= 0);
    for (final ft in floatingTexts) {
      ft.y += ft.vy;
      ft.life--;
    }
  }
}
