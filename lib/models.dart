import 'package:flutter/material.dart';

enum PlayerState { idle, attack, hurt, dead, celebrate }

class Player {
  final String id;
  final String username;
  int hp;
  int maxHp;
  double x;
  double y;
  double vx;
  double vy;
  bool facingRight;
  PlayerState state;
  int stateTimer;
  int score;
  int kills;
  Color color;
  int animFrame;
  int animTimer;
  bool onGround;
  int attackCooldown;
  bool pendingRemoval;

  Player({
    required this.id,
    required this.username,
    required this.x,
    required this.y,
    this.hp = 100,
    this.maxHp = 100,
    this.vx = 0,
    this.vy = 0,
    this.facingRight = true,
    this.state = PlayerState.idle,
    this.stateTimer = 0,
    this.score = 0,
    this.kills = 0,
    required this.color,
    this.animFrame = 0,
    this.animTimer = 0,
    this.onGround = true,
    this.attackCooldown = 0,
    this.pendingRemoval = false,
  });

  bool get isAlive => hp > 0 && state != PlayerState.dead;

  String get displayName =>
      username.length > 10 ? '${username.substring(0, 10)}..' : username;
}

class GameEvent {
  final String type;
  final String username;
  final int? value;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    required this.username,
    this.value,
    required this.timestamp,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      type: json['type'] ?? '',
      username: json['username'] ?? '',
      value: json['value'],
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class FloatingText {
  String text;
  double x;
  double y;
  double vy;
  int life;
  int maxLife;
  Color color;
  double size;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    this.vy = -1.2,
    this.life = 75,
    this.maxLife = 75,
    required this.color,
    this.size = 14,
  });
}
