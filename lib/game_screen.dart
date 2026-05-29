import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'game_engine.dart';
import 'game_canvas.dart';
import 'models.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = GameEngine();
  Timer? _gameTimer;
  Timer? _fileTimer;
  DateTime _lastFileRead = DateTime.fromMillisecondsSinceEpoch(0);
  bool _engineInited = false;
  int _joinCounter = 0;

  static const String eventsFilePath = '/sdcard/tiktok_game/events.json';

  @override
  void initState() {
    super.initState();
    // Game loop ~30 FPS — start immediately
    _gameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _engine.update();
      if (mounted) setState(() {});
    });
    // File polling
    _fileTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollEventsFile();
    });
  }

  void _initEngineIfNeeded(double canvasW, double canvasH) {
    if (_engineInited) return;
    _engineInited = true;
    final hadPlayers = _engine.players.isNotEmpty;
    _engine.init(canvasW, canvasH, 6.0);
    // Reposition existing players within new bounds
    if (hadPlayers) {
      for (final p in _engine.players) {
        p.y = _engine.groundY - 6.0 * 8;
        if (p.x > canvasW - 6.0 * 8) p.x = canvasW - 6.0 * 8;
      }
    } else {
      // Tunggu pemain dari TikTok Live
    }
  }

  void _pollEventsFile() {
    try {
      final file = File(eventsFilePath);
      if (!file.existsSync()) return;
      final stat = file.statSync();
      if (!stat.modified.isAfter(_lastFileRead)) return;
      _lastFileRead = stat.modified;

      final lines = file.readAsStringSync().trim().split('\n');
      file.writeAsStringSync('');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          _handleEvent(GameEvent.fromJson(json));
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _handleEvent(GameEvent event) {
    setState(() {
      switch (event.type) {
        case 'join':
          _engine.spawnPlayer(event.username);
          break;
        case 'comment':
          // Hanya spawn jika komentar "join" dan belum ada di game
          if ((event.keyword ?? '').toLowerCase() == 'join') {
            _engine.spawnPlayer(event.username);
          }
          break;
        case 'like':
          _engine.handleLike(event.username, event.value ?? 1);
          break;
        case 'share':
          _engine.handleShare(event.username);
          break;
      }
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _fileTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Game canvas — flexible, takes all space except bottom bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                _initEngineIfNeeded(w, h);
                return Stack(
                  children: [
                    // Canvas
                    CustomPaint(
                      painter: GamePainter(_engine),
                      size: Size(w, h),
                    ),
                    // Top HUD
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: _buildTopHUD(),
                    ),
                    // Event log top-left (below HUD)
                    Positioned(
                      top: 32, left: 0,
                      width: w * 0.46,
                      height: h * 0.28,
                      child: _buildEventLog(),
                    ),
                    // Leaderboard top-right (below HUD)
                    Positioned(
                      top: 32, right: 0,
                      width: w * 0.34,
                      height: h * 0.28,
                      child: _buildLeaderboard(),
                    ),
                  ],
                );
              },
            ),
          ),

          // Bottom controls — fixed height
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildTopHUD() {
    final alive = _engine.players.where((p) => p.isAlive).length;
    final dead = _engine.players.where((p) => !p.isAlive).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          const Text('⚔️ TIKTOK BATTLE',
            style: TextStyle(
              color: Colors.yellowAccent, fontSize: 13,
              fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2,
            )),
          const SizedBox(width: 10),
          _hudBadge('👤 $alive alive', Colors.green),
          const SizedBox(width: 6),
          _hudBadge('💀 $dead dead', Colors.red),
        ],
      ),
    );
  }

  Widget _hudBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text,
        style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
    );
  }

  Widget _buildEventLog() {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        border: Border.all(color: Colors.cyan.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📡 BATTLE LOG',
            style: TextStyle(color: Colors.cyanAccent, fontSize: 9,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Expanded(
            child: ListView.builder(
              itemCount: _engine.eventLog.length,
              itemBuilder: (_, i) => Text(_engine.eventLog[i],
                style: const TextStyle(color: Colors.white70, fontSize: 8,
                  fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    final sorted = [..._engine.players]..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.take(5).toList();

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆 TOP FIGHTERS',
            style: TextStyle(color: Colors.yellowAccent, fontSize: 9,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          ...top.asMap().entries.map((e) {
            final medal = ['🥇','🥈','🥉','4.','5.'][e.key];
            final p = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(children: [
                Text(medal, style: const TextStyle(fontSize: 8)),
                const SizedBox(width: 2),
                Expanded(child: Text(p.displayName,
                  style: TextStyle(
                    color: p.isAlive ? p.color : Colors.grey,
                    fontSize: 8, fontFamily: 'monospace',
                    decoration: p.isAlive ? null : TextDecoration.lineThrough,
                  ), overflow: TextOverflow.ellipsis)),
                Text('${p.score}',
                  style: const TextStyle(color: Colors.white, fontSize: 8,
                    fontFamily: 'monospace')),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _btn('🔃 REFRESH', Colors.cyan, () {
            _engineInited = false;
            _engine.isInited = false;
            setState(() {});
          }),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
          style: TextStyle(color: color, fontSize: 11,
            fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ),
    );
  }
}
