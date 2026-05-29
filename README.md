# TikTok Battle Game 🎮⚔️

Game pixel art retro — karakter muncul dari TikTok Live viewers, saling serang berdasarkan komentar.

---

## Struktur File

```
tiktok_battle_game/
├── lib/
│   ├── main.dart          # Entry point, landscape mode
│   ├── game_screen.dart   # UI utama + polling file
│   ├── game_engine.dart   # Logic game (spawn, damage, physics)
│   ├── game_canvas.dart   # Painter canvas Flutter
│   ├── pixel_painter.dart # Render pixel sprite + HP bar
│   └── models.dart        # Player, Event, FloatingText models
├── android/
│   └── app/src/main/AndroidManifest.xml  # Storage permission
├── .github/workflows/
│   └── build.yml          # GitHub Actions build APK
├── tiktok_live.py         # TikTok listener → tulis events.json
└── pubspec.yaml
```

---

## Cara Pakai

### 1. Build APK via GitHub Actions
- Push ke GitHub repo
- Actions otomatis build APK
- Download dari Artifacts tab

### 2. Jalankan di HP
```bash
# Termux
termux-wake-lock
python /sdcard/tiktok_game/tiktok_live.py
```

- Buka APK game
- APK polling `/sdcard/tiktok_game/events.json` tiap 500ms

---

## Kontrol Game (Tombol Test)
| Tombol | Fungsi |
|--------|--------|
| JOIN | Spawn player baru |
| LIKE | +HP player pertama |
| KANAN | Serang ke kanan |
| KIRI | Serang ke kiri |
| MUTER | Jump attack |
| SHARE | Full HP |

---

## Event dari TikTok Live
| Event | Efek di Game |
|-------|-------------|
| Join live | Spawn karakter pixel |
| Like | +HP |
| Komen "kanan" | Serang ke kanan |
| Komen "kiri" | Serang ke kiri |
| Komen "muter" | Jump spin attack |
| Share | Full HP |

---

## Tambah Keyword
Edit `KEYWORDS` di `tiktok_live.py`:
```python
KEYWORDS = ["kanan", "kiri", "muter", "lompat", "tembak"]
```

Dan tambah handler di `game_engine.dart` → `handleComment()`.
