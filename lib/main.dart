import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request storage permission di Android
  if (Platform.isAndroid) {
    await Permission.manageExternalStorage.request();
    await Permission.storage.request();
  }

  WakelockPlus.enable();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TikTokBattleApp());
}

class TikTokBattleApp extends StatelessWidget {
  const TikTokBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TikTok Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
