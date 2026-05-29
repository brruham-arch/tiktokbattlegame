import traceback
import json
import os
from datetime import datetime
from TikTokLive import TikTokLiveClient
from TikTokLive.client.web.web_settings import WebDefaults
from TikTokLive.events import (
    ConnectEvent, DisconnectEvent, CommentEvent, LikeEvent, ShareEvent,
)

WebDefaults.tiktok_sign_api_key = "euler_ODY0ZTI3ZjMyNzk2ZGE3ZDg5YTVhYjAxZTY2YmYwZTBlYjMzNjFlNmFlNDE5ODRhMjVjMDBk"
USERNAME = "@brruham"
LOG_FILE = "/sdcard/tiktok_log.txt"
EVENTS_FILE = "/sdcard/tiktok_game/events.json"
KEYWORDS = ["kanan", "kiri", "muter"]

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

@client.on(ConnectEvent)
async def on_connect(event: ConnectEvent):
    log(f"[CONNECT] Terhubung ke live {USERNAME}")
    write_event({"type": "connect", "username": USERNAME})

@client.on(DisconnectEvent)
async def on_disconnect(event: DisconnectEvent):
    log("[DISCONNECT] Koneksi terputus.")

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
    log("=" * 40)
    try:
        client.run(fetch_live_check=False)
    except KeyboardInterrupt:
        log("[STOP] Dihentikan.")
    except Exception as e:
        log(f"[ERROR] {e}")
        log(traceback.format_exc())
