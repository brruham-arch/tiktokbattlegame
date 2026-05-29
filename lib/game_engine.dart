import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

class GameEngine {
  final List<Player> players = [];
  final List<FloatingText> floatingTexts = [];
  final List<String> eventLog = [];
  final Random _rng = Random();

  double groundY = 0;
  double arenaWidth = 0;
  double arenaHeight = 0;
  double scale = 8.0;
  int tick = 0;

  // Auto battle config
  static const int attackCooldownTicks = 60; // ~2 detik per attack
  static const double attackRange = 80.0;
  static const double moveSpeed = 1.5;

  static const List<Color> playerColors = [
    Color(0xFF4FC3F7),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
    Color(0xFF80CBC4),
    Color(0xFFFFCC02),
  ];

  void init(double width, double height, double pixelScale) {
    arenaWidth = width;
    arenaHeight = height;
    scale = pixelScale;
    groundY = height - scale * 10;
  }

  Color _nextColor() {
    final used = players.map((p) => p.color).toSet();
    for (final c in playerColors) {
      if (!used.contains(c)) return c;
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
        existing.hp = existing.maxHp;
        existing.state = PlayerState.idle;
        existing.attackCooldown = 0;
        existing.x = _rng.nextDouble() * (arenaWidth - scale * 12) + scale * 2;
        existing.y = groundY - scale * 8;
        spawnFloatingText('RESPAWN!', existing.x, existing.y - scale * 4, Colors.cyanAccent, 16);
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
    spawnFloatingText('${player.displayName} joined!', x, player.y - scale * 5, player.color, 13);
    addLog('✨ ${player.displayName} joined the battle!');
    return player;
  }

  void handleLike(String username, int count) {
    final player = findPlayer(username) ?? spawnPlayer(username);
    if (!player.isAlive) {
      // Like respawns dead player
      player.hp = player.maxHp;
      player.state = PlayerState.idle;
      player.attackCooldown = 0;
      spawnFloatingText('REVIVED! ❤️', player.x, player.y - scale * 4, Colors.pinkAccent, 16);
      addLog('💗 ${player.displayName} revived by like!');
      return;
    }
    final heal = (count * 3).clamp(10, 40);
    player.hp = (player.hp + heal).clamp(0, player.maxHp);
    player.score += count;
    spawnFloatingText('+$heal HP ❤️', player.x, player.y - scale * 3, Colors.pinkAccent, 15);
    addLog('❤️ ${player.displayName} +${heal}HP');
  }

  void handleShare(String username) {
    final player = findPlayer(username) ?? spawnPlayer(username);
    player.hp = player.maxHp;
    player.state = PlayerState.celebrate;
    player.stateTimer = 40;
    spawnFloatingText('SHARE! FULL HP 🎉', player.x, player.y - scale * 4, Colors.yellowAccent, 15);
    addLog('🎉 ${player.displayName} shared — FULL HP!');
  }

  void _autoBattle(Player attacker) {
    if (!attacker.isAlive) return;
    if (attacker.attackCooldown > 0) return;
    if (attacker.state == PlayerState.hurt) return;

    // Find nearest alive enemy
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

    if (target == null) return;

    final dx = target.x - attacker.x;
    attacker.facingRight = dx > 0;

    if (minDist <= attackRange) {
      // In range — attack!
      final damage = 8 + _rng.nextInt(12); // 8-20 damage
      _applyDamage(attacker, target, damage);
      attacker.state = PlayerState.attack;
      attacker.stateTimer = 18;
      attacker.attackCooldown = attackCooldownTicks + _rng.nextInt(30);
      attacker.vx = 0;
    } else {
      // Move toward target
      final dir = dx > 0 ? 1.0 : -1.0;
      attacker.vx = dir * moveSpeed;
    }
  }

  void _applyDamage(Player attacker, Player target, int damage) {
    if (!target.isAlive) return;
    target.hp -= damage;
    target.state = PlayerState.hurt;
    target.stateTimer = 12;
    target.vx = (target.x > attacker.x ? 1 : -1) * scale * 0.5;
    target.vy = -scale * 0.3;

    spawnFloatingText('-$damage', target.x + scale * 2, target.y - scale, Colors.redAccent, 17);

    if (target.hp <= 0) {
      target.hp = 0;
      target.state = PlayerState.dead;
      target.stateTimer = 180;
      attacker.kills++;
      attacker.score += 50;
      spawnFloatingText('KO! 💀', target.x, target.y - scale * 4, Colors.red, 20);
      addLog('💀 ${attacker.displayName} KO\'d ${target.displayName}! (+50pts)');
    }
  }

  void spawnFloatingText(String text, double x, double y, Color color, double size) {
    floatingTexts.add(FloatingText(text: text, x: x, y: y, color: color, size: size));
  }

  void addLog(String msg) {
    eventLog.insert(0, msg);
    if (eventLog.length > 20) eventLog.removeLast();
  }

  void spawnDummyPlayers() {
    final names = ['brruham', 'player2', 'xXsampXx', 'ganks99'];
    for (final name in names) spawnPlayer(name);
  }

  void update() {
    tick++;

    for (final player in players) {
      // Cooldown
      if (player.attackCooldown > 0) player.attackCooldown--;

      // Auto battle
      if (player.isAlive && player.state != PlayerState.attack) {
        // Stagger AI per player so not all attack same tick
        if ((tick + players.indexOf(player) * 7) % 8 == 0) {
          _autoBattle(player);
        }
      }

      // Physics
      player.vy += 0.45; // gravity
      player.x += player.vx;
      player.y += player.vy;

      // Ground
      final floorY = groundY - scale * 8;
      if (player.y >= floorY) {
        player.y = floorY;
        player.vy = 0;
        player.onGround = true;
      } else {
        player.onGround = false;
      }

      // Walls
      if (player.x < scale) { player.x = scale; player.vx *= -0.3; }
      if (player.x > arenaWidth - scale * 9) { player.x = arenaWidth - scale * 9; player.vx *= -0.3; }

      // Friction
      player.vx *= 0.88;
      if (player.vx.abs() < 0.05) player.vx = 0;

      // State timer
      if (player.stateTimer > 0) {
        player.stateTimer--;
        if (player.stateTimer == 0 && player.state != PlayerState.dead) {
          player.state = PlayerState.idle;
        }
      }

      // Animation
      player.animTimer++;
      if (player.animTimer >= 18) {
        player.animTimer = 0;
        player.animFrame = (player.animFrame + 1) % 2;
      }

      // Auto respawn after death timer
      if (player.state == PlayerState.dead && player.stateTimer == 0) {
        // stay dead, need like to revive
      }
    }

    // Floating texts
    floatingTexts.removeWhere((ft) => ft.life <= 0);
    for (final ft in floatingTexts) {
      ft.y += ft.vy;
      ft.life--;
    }
  }
}
