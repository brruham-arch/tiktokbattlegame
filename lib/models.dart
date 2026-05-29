import 'package:flutter/material.dart';
import 'dart:math';

enum SpinnerState { alive, dead }

class Spinner {
  final String username;
  double x;
  double y;
  double vx;
  double vy;
  double size;       // radius
  double maxSize;
  int hp;
  int maxHp;
  double angle;      // rotation angle untuk animasi spin
  double spinSpeed;  // kecepatan rotasi
  Color color;
  SpinnerState state;
  int deadTimer;     // countdown sebelum benar-benar dihapus
  int score;
  bool pendingRemoval;
  String? avatarPath; // path lokal foto profil

  static const double minSize = 18.0;
  static const double maxSizeCap = 72.0;
  static const double baseSpeed = 2.8;

  Spinner({
    required this.username,
    required this.x,
    required this.y,
    required this.color,
    this.size = 28.0,
    this.hp = 100,
    this.vx = 0,
    this.vy = 0,
    this.angle = 0,
    this.score = 0,
    this.state = SpinnerState.alive,
    this.deadTimer = 0,
    this.pendingRemoval = false,
  })  : maxSize = 28.0,
        maxHp = 100,
        spinSpeed = 0.12;

  bool get isAlive => state == SpinnerState.alive && hp > 0;

  // Kecepatan berbanding terbalik dengan ukuran (fisika)
  double get speed => (baseSpeed * (minSize / size)).clamp(0.6, baseSpeed);

  String get displayName =>
      username.length > 10 ? '${username.substring(0, 10)}..' : username;

  void addSize(double amount) {
    size = (size + amount).clamp(minSize, maxSizeCap);
    maxSize = size;
    // HP ikut naik proporsional
    final ratio = size / maxSizeCap;
    maxHp = (50 + (ratio * 200)).round();
    hp = (hp + amount * 2).round().clamp(0, maxHp);
    // Spin makin besar makin lambat
    spinSpeed = (0.18 - (size / maxSizeCap) * 0.12).clamp(0.04, 0.18);
  }

  void takeDamage(int dmg) {
    hp -= dmg;
    final shrink = (dmg * 0.15).clamp(0.5, 4.0);
    size = (size - shrink).clamp(minSize, maxSizeCap);
    if (hp <= 0) {
      hp = 0;
      state = SpinnerState.dead;
      deadTimer = 90;
    }
  }

  void revive(double ax, double ay) {
    x = ax; y = ay;
    size = 28.0; maxSize = 28.0;
    hp = 100; maxHp = 100;
    spinSpeed = 0.12;
    state = SpinnerState.alive;
    deadTimer = 0;
    pendingRemoval = false;
    final rng = Random();
    final spd = speed;
    final angle = rng.nextDouble() * pi * 2;
    vx = cos(angle) * spd;
    vy = sin(angle) * spd;
  }
}

class GameEvent {
  final String type;
  final String username;
  final int? value;
  final String? keyword;
  final String? comment;
  final String? avatarPath;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    required this.username,
    this.value,
    this.keyword,
    this.comment,
    this.avatarPath,
    required this.timestamp,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      type: json['type'] ?? '',
      username: json['username'] ?? '',
      value: json['value'],
      keyword: json['keyword'],
      comment: json['comment'],
      avatarPath: json['avatar_path'],
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
    this.vy = -1.0,
    this.life = 70,
    this.maxLife = 70,
    required this.color,
    this.size = 13,
  });
}
