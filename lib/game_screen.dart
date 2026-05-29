import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
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
  final Map<String, ui.Image?> _avatarImages = {};
  Timer? _gameTimer;
  Timer? _fileTimer;
  bool _engineInited = false;

  static const String eventsFilePath = '/sdcard/tiktok_game/events.json';
  static const String avatarDir = '/sdcard/tiktok_game/avatars';

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

  Future<void> _loadAvatar(String username, String? avatarPath) async {
    if (_avatarImages.containsKey(username)) return;
    if (avatarPath == null) { _avatarImages[username] = null; return; }
    try {
      final file = File(avatarPath);
      if (!file.existsSync()) { _avatarImages[username] = null; return; }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 128, targetHeight: 128);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _avatarImages[username] = frame.image);
    } catch (_) {
      _avatarImages[username] = null;
    }
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
          final avatarPath = event.avatarPath;
          final s = _engine.spawnSpinner(event.username, avatarPath: avatarPath);
          if (avatarPath != null) _loadAvatar(event.username, avatarPath);
          break;
        case 'comment':
          if ((event.keyword ?? '').toLowerCase() == 'join') {
            _engine.spawnSpinner(event.username, avatarPath: event.avatarPath);
          }
          _engine.handleComment(event.username);
          if (event.avatarPath != null) _loadAvatar(event.username, event.avatarPath);
          break;
        case 'like':
          _engine.handleLike(event.username, event.value ?? 1);
          if (event.avatarPath != null) _loadAvatar(event.username, event.avatarPath);
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
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // Arena = semua kecuali HUD atas (36) dan panel bawah (110)
        const topH = 36.0;
        const bottomH = 110.0;
        final arenaH = h - topH - bottomH;
        _initEngineIfNeeded(w, arenaH);

        return Column(children: [
          _buildTopHUD(),
          SizedBox(
            width: w,
            height: arenaH,
            child: CustomPaint(
              painter: GamePainter(_engine, _avatarImages),
              size: Size(w, arenaH),
            ),
          ),
          _buildBottomPanel(w, bottomH),
        ]);
      }),
    );
  }

  Widget _buildTopHUD() {
    final alive = _engine.spinners.where((s) => s.isAlive).length;
    final total = _engine.spinners.length;
    return Container(
      height: 36,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        const Text('🌀 GASING BATTLE',
            style: TextStyle(color: Colors.cyanAccent, fontSize: 12,
                fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const Spacer(),
        _badge('🌀 $alive/$total', Colors.cyan),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            _engineInited = false;
            _engine.isInited = false;
          }),
          child: _badge('🔃', Colors.cyan),
        ),
      ]),
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

  Widget _buildBottomPanel(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: const Color(0xFF080812),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Log panel kiri
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            ]),
          ),
        ),
        const SizedBox(width: 6),
        // Leaderboard kanan
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              border: Border.all(color: Colors.yellowAccent.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🏆 TOP',
                  style: TextStyle(color: Colors.yellowAccent, fontSize: 8,
                      fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              ...([..._engine.spinners]
                ..sort((a, b) => b.score.compareTo(a.score)))
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map((e) {
                final medal = ['🥇', '🥈', '🥉', '4.', '5.'][e.key];
                final s = e.value;
                return Text('$medal ${s.displayName} ${s.score}',
                    style: TextStyle(
                      color: s.isAlive ? s.color : Colors.grey,
                      fontSize: 8, fontFamily: 'monospace',
                      decoration: s.isAlive ? null : TextDecoration.lineThrough,
                    ),
                    overflow: TextOverflow.ellipsis);
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}
