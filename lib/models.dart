import 'package:flutter/material.dart';
import 'dart:math';

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
  });

  bool get isAlive => hp > 0;

  String get displayName =>
      username.length > 10 ? '${username.substring(0, 10)}..' : username;
}

class GameEvent {
  final String type;
  final String username;
  final String? targetUsername;
  final int? value;
  final String? keyword;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    required this.username,
    this.targetUsername,
    this.value,
    this.keyword,
    required this.timestamp,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      type: json['type'] ?? '',
      username: json['username'] ?? '',
      targetUsername: json['target'],
      value: json['value'],
      keyword: json['keyword'],
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
    this.vy = -1.5,
    this.life = 80,
    this.maxLife = 80,
    required this.color,
    this.size = 14,
  });
}

class Projectile {
  double x;
  double y;
  double vx;
  double vy;
  String ownerId;
  int damage;
  int life;
  Color color;

  Projectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ownerId,
    this.damage = 10,
    this.life = 40,
    required this.color,
  });
}
