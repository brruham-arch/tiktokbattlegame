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
  bool _engineInited = false;

  static const String eventsFilePath = '/sdcard/tiktok_game/events.json';

  @override
  void initState() {
    super.initState();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _engine.update();
      if (mounted) setState(() {});
    });
    _fileTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollEventsFile();
    });
  }

  void _initEngineIfNeeded(double w, double h) {
    if (_engineInited) return;
    _engineInited = true;
    _engine.init(w, h);
  }

  void _pollEventsFile() {
    try {
      final file = File(eventsFilePath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync().trim();
      if (content.isEmpty) return;
      file.writeAsStringSync('');
      for (final line in content.split('\n')) {
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
          _engine.spawnSpinner(event.username);
          break;
        case 'comment':
          // Semua komentar = +10 ukuran, komentar "join" juga spawn
          if ((event.keyword ?? '').toLowerCase() == 'join') {
            _engine.spawnSpinner(event.username);
          }
          _engine.handleComment(event.username);
          break;
        case 'like':
          _engine.handleLike(event.username, event.value ?? 1);
          break;
        case 'share':
          _engine.handleLike(event.username, 10);
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          _initEngineIfNeeded(w, h - 80); // 80 = HUD atas + bawah
          return Column(
            children: [
              _buildTopHUD(),
              Expanded(
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: GamePainter(_engine),
                      size: Size(w, h - 80),
                    ),
                    Positioned(
                      top: 4, left: 4,
                      width: w * 0.44,
                      height: (h - 80) * 0.3,
                      child: _buildEventLog(),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      width: w * 0.36,
                      height: (h - 80) * 0.3,
                      child: _buildLeaderboard(),
                    ),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopHUD() {
    final alive = _engine.spinners.where((s) => s.isAlive).length;
    final total = _engine.spinners.length;
    return Container(
      height: 36,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Text('🌀 GASING BATTLE',
            style: TextStyle(
              color: Colors.cyanAccent, fontSize: 12,
              fontFamily: 'monospace', fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            )),
          const Spacer(),
          _badge('🌀 $alive/${total}', Colors.cyan),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
        style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
    );
  }

  Widget _buildEventLog() {
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📡 LOG',
            style: TextStyle(color: Colors.cyanAccent, fontSize: 8,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Expanded(
            child: ListView.builder(
              itemCount: _engine.eventLog.length,
              itemBuilder: (_, i) => Text(_engine.eventLog[i],
                style: const TextStyle(color: Colors.white70, fontSize: 8,
                  fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    final sorted = [..._engine.spinners]..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.take(5).toList();
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆 TOP',
            style: TextStyle(color: Colors.yellowAccent, fontSize: 8,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          ...top.asMap().entries.map((e) {
            final medal = ['🥇','🥈','🥉','4.','5.'][e.key];
            final s = e.value;
            return Text('$medal ${s.displayName} ${s.score}',
              style: TextStyle(
                color: s.isAlive ? s.color : Colors.grey,
                fontSize: 8, fontFamily: 'monospace',
                decoration: s.isAlive ? null : TextDecoration.lineThrough,
              ),
              overflow: TextOverflow.ellipsis);
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 44,
      color: Colors.black,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
