import traceback
import json
import os
import asyncio
import httpx
from datetime import datetime
from TikTokLive import TikTokLiveClient
from TikTokLive.client.web.web_settings import WebDefaults
from TikTokLive.events import (
    ConnectEvent, DisconnectEvent, CommentEvent, LikeEvent, ShareEvent,
    JoinEvent,
)

WebDefaults.tiktok_sign_api_key = "euler_ODY0ZTI3ZjMyNzk2ZGE3ZDg5YTVhYjAxZTY2YmYwZTBlYjMzNjFlNmFlNDE5ODRhMjVjMDBk"
USERNAME = "@brruham"
LOG_FILE = "/sdcard/tiktok_log.txt"
EVENTS_FILE = "/sdcard/tiktok_game/events.json"
AVATAR_DIR = "/sdcard/tiktok_game/avatars"
KEYWORDS = ["kanan", "kiri", "muter", "join"]

client = TikTokLiveClient(unique_id=USERNAME)

def log(text):
    print(text)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(text + "\n")
    except Exception as e:
        print(f"[LOG ERROR] {e}")

def write_event(event_dict):
    """Append event as JSON line to events file for Flutter to read."""
    try:
        os.makedirs(os.path.dirname(EVENTS_FILE), exist_ok=True)
        event_dict["timestamp"] = datetime.now().isoformat()
        with open(EVENTS_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(event_dict) + "\n")
    except Exception as e:
        log(f"[EVENT ERROR] {e}")

async def download_avatar(username: str, url: str) -> str | None:
    """Download foto profil, simpan ke AVATAR_DIR/username.jpg. Return path lokal."""
    if not url:
        return None
    safe_name = "".join(c if c.isalnum() or c in "-_." else "_" for c in username)
    path = os.path.join(AVATAR_DIR, f"{safe_name}.jpg")
    # Kalau sudah ada, skip download
    if os.path.exists(path):
        return path
    try:
        os.makedirs(AVATAR_DIR, exist_ok=True)
        async with httpx.AsyncClient(timeout=8) as client_http:
            r = await client_http.get(url)
            if r.status_code == 200:
                with open(path, "wb") as f:
                    f.write(r.content)
                log(f"[AVATAR] {username} → {path}")
                return path
    except Exception as e:
        log(f"[AVATAR ERROR] {username}: {e}")
    return None

def get_avatar_url(user) -> str | None:
    """Ambil URL foto profil dari user object."""
    if not user:
        return None
    # Coba beberapa atribut yang mungkin ada di versi berbeda
    for attr in ['avatar_thumb', 'avatar_larger', 'avatar_medium']:
        obj = getattr(user, attr, None)
        if obj:
            url = getattr(obj, 'url_list', None)
            if url and len(url) > 0:
                return url[0]
            url = getattr(obj, 'url', None)
            if url:
                return url
    # Fallback langsung
    url = getattr(user, 'profile_picture_url', None) or getattr(user, 'avatar_url', None)
    return url

@client.on(ConnectEvent)
async def on_connect(event: ConnectEvent):
    log(f"[CONNECT] Terhubung ke live {USERNAME}")
    write_event({"type": "connect", "username": USERNAME})

@client.on(DisconnectEvent)
async def on_disconnect(event: DisconnectEvent):
    log("[DISCONNECT] Koneksi terputus.")

@client.on(JoinEvent)
async def on_join(event: JoinEvent):
    user = event.user.nickname if event.user else "unknown"
    log(f"[JOIN] {user} masuk live")
    avatar_url = get_avatar_url(event.user)
    avatar_path = await download_avatar(user, avatar_url) if avatar_url else None
    write_event({
        "type": "join",
        "username": user,
        "avatar_path": avatar_path,
    })

@client.on(LikeEvent)
async def on_like(event: LikeEvent):
    user = event.user.nickname if event.user else "unknown"
    count = getattr(event, 'count', 1) or 1
    total = getattr(event, 'total', '?')
    log(f"[LIKE] {user} +{count} | Total: {total}")
    write_event({
        "type": "like",
        "username": user,
        "value": count,
    })

@client.on(CommentEvent)
async def on_comment(event: CommentEvent):
    user = event.user.nickname if event.user else "unknown"
    comment = event.comment if event.comment else ""
    log(f"[KOMEN] {user}: {comment}")

    matched_keyword = None
    for keyword in KEYWORDS:
        if keyword in comment.lower():
            matched_keyword = keyword
            log(f"[KEYWORD:{keyword.upper()}] {user}: {comment}")
            break

    # Download avatar kalau belum ada
    avatar_url = get_avatar_url(event.user)
    safe_name = "".join(c if c.isalnum() or c in "-_." else "_" for c in user)
    avatar_path = os.path.join(AVATAR_DIR, f"{safe_name}.jpg")
    if not os.path.exists(avatar_path) and avatar_url:
        asyncio.ensure_future(download_avatar(user, avatar_url))

    write_event({
        "type": "comment",
        "username": user,
        "comment": comment,
        "keyword": matched_keyword,
    })

@client.on(ShareEvent)
async def on_share(event: ShareEvent):
    user = event.user.nickname if event.user else "unknown"
    log(f"[SHARE] {user} membagikan live ini!")
    write_event({
        "type": "share",
        "username": user,
    })

if __name__ == "__main__":
    log("=" * 40)
    log(f"Username  : {USERNAME}")
    log(f"Keywords  : {', '.join(KEYWORDS)} + like")
    log(f"Events    : {EVENTS_FILE}")
    log(f"Avatars   : {AVATAR_DIR}")
    log("=" * 40)
    try:
        client.run(fetch_live_check=False)
    except KeyboardInterrupt:
        log("[STOP] Dihentikan.")
    except Exception as e:
        log(f"[ERROR] {e}")
        log(traceback.format_exc())
