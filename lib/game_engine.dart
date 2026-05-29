import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

class GameEngine {
  final List<Player> players = [];
  final List<FloatingText> floatingTexts = [];
  final List<Projectile> projectiles = [];
  final List<String> eventLog = [];
  final Random _rng = Random();

  double groundY = 0;
  double arenaWidth = 0;
  double arenaHeight = 0;
  double scale = 8.0;

  int tick = 0;

  static const List<Color> playerColors = [
    Color(0xFF4FC3F7), // cyan
    Color(0xFFEF5350), // red
    Color(0xFF66BB6A), // green
    Color(0xFFFFCA28), // yellow
    Color(0xFFAB47BC), // purple
    Color(0xFFFF7043), // orange
    Color(0xFF26C6DA), // teal
    Color(0xFFEC407A), // pink
  ];

  void init(double width, double height, double pixelScale) {
    arenaWidth = width;
    arenaHeight = height;
    scale = pixelScale;
    groundY = height - scale * 10;
  }

  Color _nextColor() {
    final usedColors = players.map((p) => p.color).toSet();
    for (final c in playerColors) {
      if (!usedColors.contains(c)) return c;
    }
    return playerColors[_rng.nextInt(playerColors.length)];
  }

  Player? findPlayer(String username) {
    try {
      return players.firstWhere(
        (p) => p.username.toLowerCase() == username.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Player spawnPlayer(String username) {
    final existing = findPlayer(username);
    if (existing != null) {
      if (!existing.isAlive) {
        // Respawn
        existing.hp = existing.maxHp;
        existing.state = PlayerState.idle;
        existing.x = _rng.nextDouble() * (arenaWidth - scale * 10) + scale;
        existing.y = groundY - scale * 8;
        spawnFloatingText('RESPAWN!', existing.x, existing.y - scale * 4,
            Colors.cyanAccent, 16);
        addLog('🔄 ${existing.displayName} respawned!');
      }
      return existing;
    }

    final x = _rng.nextDouble() * (arenaWidth - scale * 12) + scale * 2;
    final player = Player(
      id: username,
      username: username,
      x: x,
      y: groundY - scale * 8,
      color: _nextColor(),
      facingRight: x < arenaWidth / 2,
    );
    players.add(player);

    spawnFloatingText(
        '${player.displayName} JOINED!', x, player.y - scale * 4,
        player.color, 14);
    addLog('✨ ${player.displayName} joined the battle!');
    return player;
  }

  void handleLike(String username, int count) {
    final player = findPlayer(username) ?? spawnPlayer(username);
    if (!player.isAlive) return;

    final heal = (count * 2).clamp(5, 30);
    player.hp = (player.hp + heal).clamp(0, player.maxHp);
    player.state = PlayerState.celebrate;
    player.stateTimer = 30;
    player.score += count;

    spawnFloatingText('+$heal HP ❤️', player.x, player.y - scale * 2,
        Colors.pinkAccent, 16);
    addLog('❤️ ${player.displayName} +${heal}HP from $count likes!');
  }

  void handleComment(String username, String keyword) {
    final attacker = findPlayer(username) ?? spawnPlayer(username);
    if (!attacker.isAlive) return;

    // Find nearest enemy
    Player? target;
    double minDist = double.infinity;
    for (final p in players) {
      if (p.id == attacker.id || !p.isAlive) continue;
      final dx = p.x - attacker.x;
      final dy = p.y - attacker.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < minDist) {
        minDist = dist;
        target = p;
      }
    }

    if (target == null) {
      spawnFloatingText('No target!', attacker.x, attacker.y - scale * 3,
          Colors.grey, 12);
      return;
    }

    int damage = 15;
    String actionText = 'PUNCH!';

    switch (keyword.toLowerCase()) {
      case 'kanan':
        attacker.facingRight = true;
        attacker.vx = scale * 0.5;
        damage = 12;
        actionText = '👊 KANAN!';
        break;
      case 'kiri':
        attacker.facingRight = false;
        attacker.vx = -scale * 0.5;
        damage = 12;
        actionText = '👊 KIRI!';
        break;
      case 'muter':
        attacker.vx = (attacker.facingRight ? 1 : -1) * scale * 0.3;
        attacker.vy = -scale * 0.8;
        damage = 8;
        actionText = '🌀 MUTER!';
        break;
    }

    applyDamage(attacker, target, damage);
    attacker.state = PlayerState.attack;
    attacker.stateTimer = 20;
    attacker.facingRight = target.x > attacker.x;

    spawnFloatingText(actionText, attacker.x, attacker.y - scale * 4,
        attacker.color, 14);
    addLog('⚔️ ${attacker.displayName} → ${target.displayName} $actionText ($damage dmg)');
  }

  void handleShare(String username) {
    final player = findPlayer(username) ?? spawnPlayer(username);
    player.hp = player.maxHp; // full heal on share
    player.state = PlayerState.celebrate;
    player.stateTimer = 40;
    spawnFloatingText('SHARE! FULL HP! 🎉', player.x, player.y - scale * 4,
        Colors.yellowAccent, 16);
    addLog('🎉 ${player.displayName} shared — FULL HP!');
  }

  void applyDamage(Player attacker, Player target, int damage) {
    if (!target.isAlive) return;
    target.hp -= damage;
    target.state = PlayerState.hurt;
    target.stateTimer = 15;

    // Knockback
    target.vx = (target.x > attacker.x ? 1 : -1) * scale * 0.6;
    target.vy = -scale * 0.4;

    spawnFloatingText('-$damage', target.x + scale * 2, target.y - scale,
        Colors.redAccent, 18);

    if (target.hp <= 0) {
      target.hp = 0;
      target.state = PlayerState.dead;
      target.stateTimer = 120;
      attacker.kills++;
      attacker.score += 50;
      spawnFloatingText('KO! 💀', target.x, target.y - scale * 4,
          Colors.red, 20);
      addLog('💀 ${attacker.displayName} KO\'d ${target.displayName}!');
    }
  }

  void spawnFloatingText(
      String text, double x, double y, Color color, double size) {
    floatingTexts.add(FloatingText(
      text: text,
      x: x,
      y: y,
      color: color,
      size: size,
    ));
  }

  void addLog(String msg) {
    eventLog.insert(0, msg);
    if (eventLog.length > 20) eventLog.removeLast();
  }

  void spawnDummyPlayers() {
    final names = ['brruham', 'player2', 'xXsampXx', 'ganks99', 'rudianto'];
    for (final name in names) {
      spawnPlayer(name);
    }
  }

  void update() {
    tick++;

    // Update players
    for (final player in players) {
      // Physics
      if (!player.onGround) {
        player.vy += 0.5; // gravity
      }

      player.x += player.vx;
      player.y += player.vy;

      // Ground collision
      if (player.y >= groundY - scale * 8) {
        player.y = groundY - scale * 8;
        player.vy = 0;
        player.onGround = true;
      } else {
        player.onGround = false;
      }

      // Wall bounce
      if (player.x < scale) {
        player.x = scale;
        player.vx *= -0.5;
      }
      if (player.x > arenaWidth - scale * 9) {
        player.x = arenaWidth - scale * 9;
        player.vx *= -0.5;
      }

      // Friction
      player.vx *= 0.85;
      if (player.vx.abs() < 0.1) player.vx = 0;

      // State timer
      if (player.stateTimer > 0) {
        player.stateTimer--;
        if (player.stateTimer == 0 && player.state != PlayerState.dead) {
          player.state = PlayerState.idle;
        }
      }

      // Animation
      player.animTimer++;
      if (player.animTimer >= 20) {
        player.animTimer = 0;
        player.animFrame = (player.animFrame + 1) % 2;
      }

      // AI wander for alive players (slow random movement)
      if (player.isAlive && tick % 120 == players.indexOf(player) % 120) {
        player.vx += (_rng.nextDouble() - 0.5) * scale * 0.3;
      }

      // Respawn dead players after timer
      if (player.state == PlayerState.dead && player.stateTimer == 0) {
        // Stay dead, wait for rejoin
      }
    }

    // Update floating texts
    floatingTexts.removeWhere((ft) => ft.life <= 0);
    for (final ft in floatingTexts) {
      ft.y += ft.vy;
      ft.life--;
    }
  }
}
