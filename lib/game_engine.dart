import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';

class GameEngine {
  final List<Player> players = [];
  final List<FloatingText> floatingTexts = [];
  final List<String> eventLog = [];
  final Random _rng = Random();

  double groundY = 300;
  double arenaWidth = 400;
  double arenaHeight = 400;
  double scale = 6.0;
  int tick = 0;
  bool isInited = false;

  static const int attackCooldownTicks = 50;
  static const double attackRange = 70.0;
  static const double moveSpeed = 1.2;

  static const List<Color> playerColors = [
    Color(0xFF4FC3F7), Color(0xFFEF5350), Color(0xFF66BB6A),
    Color(0xFFFFCA28), Color(0xFFAB47BC), Color(0xFFFF7043),
    Color(0xFF26C6DA), Color(0xFFEC407A), Color(0xFF80CBC4), Color(0xFFFFCC02),
  ];

  void init(double width, double height, double pixelScale) {
    arenaWidth = width;
    arenaHeight = height;
    scale = pixelScale;
    // groundY = 85% of canvas height — players spawn above this line
    groundY = height * 0.85;
    isInited = true;
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
      // Sudah ada dan masih hidup — tidak spawn ulang
      if (existing.isAlive) return existing;
      // Sudah mati — tidak bisa join lagi, harus like dulu
      spawnFloatingText('Already KO!', existing.x, existing.y - 20, Colors.grey, 12);
      return existing;
    }

    final x = _rng.nextDouble() * (arenaWidth - scale * 14) + scale * 2;
    final y = groundY - scale * 8; // spawn just above ground
    final player = Player(
      id: username,
      username: username,
      x: x,
      y: y,
      color: _nextColor(),
      facingRight: x < arenaWidth / 2,
    );
    players.add(player);
    spawnFloatingText('${player.displayName} joined!', x, y - 20, player.color, 12);
    addLog('✨ ${player.displayName} joined the battle!');
    return player;
  }

  void handleLike(String username, int count) {
    final player = findPlayer(username) ?? spawnPlayer(username);
    if (!player.isAlive) {
      player.hp = player.maxHp;
      player.state = PlayerState.idle;
      player.attackCooldown = 0;
      spawnFloatingText('REVIVED! ❤️', player.x, player.y - 20, Colors.pinkAccent, 14);
      addLog('💗 ${player.displayName} revived!');
      return;
    }
    final heal = (count * 3).clamp(10, 40);
    player.hp = (player.hp + heal).clamp(0, player.maxHp);
    player.score += count;
    spawnFloatingText('+$heal HP ❤️', player.x, player.y - 20, Colors.pinkAccent, 14);
    addLog('❤️ ${player.displayName} +${heal}HP');
  }

  void handleShare(String username) {
    final player = findPlayer(username) ?? spawnPlayer(username);
    player.hp = player.maxHp;
    player.state = PlayerState.celebrate;
    player.stateTimer = 40;
    spawnFloatingText('FULL HP 🎉', player.x, player.y - 20, Colors.yellowAccent, 14);
    addLog('🎉 ${player.displayName} shared — FULL HP!');
  }

  void _autoBattle(Player attacker) {
    if (!attacker.isAlive) return;
    if (attacker.attackCooldown > 0) return;
    if (attacker.state == PlayerState.hurt) return;

    Player? target;
    double minDist = double.infinity;
    for (final p in players) {
      if (p.id == attacker.id || !p.isAlive) continue;
      final dx = p.x - attacker.x;
      final dy = p.y - attacker.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < minDist) { minDist = dist; target = p; }
    }
    if (target == null) return;

    final dx = target.x - attacker.x;
    attacker.facingRight = dx > 0;

    if (minDist <= attackRange) {
      final damage = 8 + _rng.nextInt(12);
      _applyDamage(attacker, target, damage);
      attacker.state = PlayerState.attack;
      attacker.stateTimer = 18;
      attacker.attackCooldown = attackCooldownTicks + _rng.nextInt(30);
      attacker.vx = 0;
    } else {
      attacker.vx = (dx > 0 ? 1.0 : -1.0) * moveSpeed;
    }
  }

  void _applyDamage(Player attacker, Player target, int damage) {
    if (!target.isAlive) return;
    target.hp -= damage;
    target.state = PlayerState.hurt;
    target.stateTimer = 12;
    target.vx = (target.x > attacker.x ? 1 : -1) * scale * 0.5;
    target.vy = -scale * 0.3;
    spawnFloatingText('-$damage', target.x + scale * 2, target.y - scale, Colors.redAccent, 16);

    if (target.hp <= 0) {
      target.hp = 0;
      target.state = PlayerState.dead;
      target.stateTimer = 60;
      attacker.kills++;
      attacker.score += 50;
      spawnFloatingText('KO! 💀', target.x, target.y - 20, Colors.red, 18);
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

  void update() {
    if (!isInited) return;
    tick++;

    for (final player in players) {
      if (player.attackCooldown > 0) player.attackCooldown--;

      if (player.isAlive && player.state != PlayerState.attack) {
        if ((tick + players.indexOf(player) * 7) % 8 == 0) {
          _autoBattle(player);
        }
      }

      // Physics
      player.vy += 0.45;
      player.x += player.vx;
      player.y += player.vy;

      // Ground clamp
      final floorY = groundY - scale * 8;
      if (player.y >= floorY) {
        player.y = floorY;
        player.vy = 0;
        player.onGround = true;
      } else {
        player.onGround = false;
      }

      // Wall clamp
      if (player.x < 0) { player.x = 0; player.vx *= -0.3; }
      if (player.x > arenaWidth - scale * 8) { player.x = arenaWidth - scale * 8; player.vx *= -0.3; }

      player.vx *= 0.88;
      if (player.vx.abs() < 0.05) player.vx = 0;

      if (player.stateTimer > 0) {
        player.stateTimer--;
        if (player.stateTimer == 0 && player.state != PlayerState.dead) {
          player.state = PlayerState.idle;
        }
      }
      // Mark dead players for removal after timer
      if (player.state == PlayerState.dead && player.stateTimer == 0) {
        player.pendingRemoval = true;
      }

      player.animTimer++;
      if (player.animTimer >= 18) {
        player.animTimer = 0;
        player.animFrame = (player.animFrame + 1) % 2;
      }
    }

    // Remove dead players
    players.removeWhere((p) => p.pendingRemoval);

    floatingTexts.removeWhere((ft) => ft.life <= 0);
    for (final ft in floatingTexts) {
      ft.y += ft.vy;
      ft.life--;
    }
  }
}
