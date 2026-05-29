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
  bool _showLog = true;
  bool _showControls = true;
  DateTime _lastFileRead = DateTime.fromMillisecondsSinceEpoch(0);

  static const String eventsFilePath = '/sdcard/tiktok_game/events.json';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGame();
    });
  }

  void _initGame() {
    final size = MediaQuery.of(context).size;
    _engine.init(size.width, size.height * 0.75, 8.0);
    _engine.spawnDummyPlayers();

    // Game loop ~30 FPS
    _gameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _engine.update();
      if (mounted) setState(() {});
    });

    // File polling every 500ms
    _fileTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollEventsFile();
    });
  }

  void _pollEventsFile() {
    try {
      final file = File(eventsFilePath);
      if (!file.existsSync()) return;

      final stat = file.statSync();
      if (stat.modified.isAfter(_lastFileRead)) {
        _lastFileRead = stat.modified;
        final content = file.readAsStringSync();
        final lines = content.trim().split('\n');

        for (final line in lines.reversed) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            _handleEvent(GameEvent.fromJson(json));
          } catch (_) {}
        }

        // Clear file after reading
        file.writeAsStringSync('');
      }
    } catch (_) {}
  }

  void _handleEvent(GameEvent event) {
    setState(() {
      switch (event.type) {
        case 'join':
          _engine.spawnPlayer(event.username);
          break;
        case 'like':
          _engine.handleLike(event.username, event.value ?? 1);
          break;
        case 'comment':
          if (event.keyword != null) {
            _engine.handleComment(event.username, event.keyword!);
          } else {
            _engine.spawnPlayer(event.username);
          }
          break;
        case 'share':
          _engine.handleShare(event.username);
          break;
      }
    });
  }

  // Manual test buttons
  void _testJoin() {
    final names = ['viewer${_engine.players.length + 1}', 'user_${DateTime.now().second}'];
    _engine.spawnPlayer(names[0]);
    setState(() {});
  }

  void _testLike() {
    if (_engine.players.isEmpty) return;
    final player = _engine.players[0];
    _engine.handleLike(player.username, 5);
    setState(() {});
  }

  void _testAttack(String keyword) {
    if (_engine.players.isEmpty) return;
    final player = _engine.players[0];
    _engine.handleComment(player.username, keyword);
    setState(() {});
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _fileTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Game canvas
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.78,
            child: CustomPaint(
              painter: GamePainter(_engine),
              size: Size(size.width, size.height * 0.78),
            ),
          ),

          // Top HUD
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopHUD(),
          ),

          // Event log panel (bottom left)
          if (_showLog)
            Positioned(
              bottom: 60,
              left: 0,
              width: size.width * 0.45,
              height: size.height * 0.25,
              child: _buildEventLog(),
            ),

          // Leaderboard (bottom right)
          Positioned(
            bottom: 60,
            right: 0,
            width: size.width * 0.35,
            height: size.height * 0.25,
            child: _buildLeaderboard(),
          ),

          // Control buttons (bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 55,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Title
          const Text(
            '⚔️ TIKTOK BATTLE',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          // Player count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.4),
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '👤 ${_engine.players.where((p) => p.isAlive).length}/${_engine.players.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const Spacer(),
          // Toggle log button
          GestureDetector(
            onTap: () => setState(() => _showLog = !_showLog),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _showLog ? 'LOG ✓' : 'LOG',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLog() {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📡 BATTLE LOG',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _engine.eventLog.length,
              itemBuilder: (ctx, i) => Text(
                _engine.eventLog[i],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    final sorted = [..._engine.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.take(5).toList();

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        border: Border.all(color: Colors.yellowAccent.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 TOP FIGHTERS',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          ...top.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final medal = ['🥇', '🥈', '🥉', '4.', '5.'][i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(medal,
                      style: const TextStyle(fontSize: 8)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      p.displayName,
                      style: TextStyle(
                        color: p.isAlive ? p.color : Colors.grey,
                        fontSize: 8,
                        fontFamily: 'monospace',
                        decoration: p.isAlive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${p.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlBtn('➕ JOIN', Colors.cyan, _testJoin),
          _ctrlBtn('❤️ LIKE', Colors.pink, _testLike),
          _ctrlBtn('👊 KANAN', Colors.orange, () => _testAttack('kanan')),
          _ctrlBtn('👊 KIRI', Colors.orange, () => _testAttack('kiri')),
          _ctrlBtn('🌀 MUTER', Colors.purple, () => _testAttack('muter')),
          _ctrlBtn('🎉 SHARE', Colors.green, () {
            if (_engine.players.isNotEmpty) {
              _engine.handleShare(_engine.players[0].username);
              setState(() {});
            }
          }),
        ],
      ),
    );
  }

  Widget _ctrlBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
