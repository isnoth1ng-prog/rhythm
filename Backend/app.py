from __future__ import annotations

import asyncio
import re
from typing import Any

from fastapi import FastAPI, Query
from pydantic import BaseModel
from yt_dlp import YoutubeDL

app = FastAPI(title="Rhythm Backend", version="1.0.0")

NOISE = [
    r"\\[[^\\]]*(?:official|video|audio|lyrics|hd|4k|premiere|премьера|клип)[^\\]]*\\]",
    r"\\([^\\)]*(?:official|video|audio|lyrics|prod(?:uced)?\\.?\\s*by|премьера|клип)[^\\)]*\\)",
    r"#\\w+",
    r"\\b(?:official|music video|official audio|full hd|4k|hq|lyrics|lyric video|премьера|клип|скачать|download)\\b",
    r"[🔥💥⭐️✨🎵🎶❤️]+",
]

VERSION_PATTERNS = {
    "Slowed + Reverb": r"\\bslowed(?:\\s*\\+\\s*|\\s+and\\s+)reverb\\b",
    "Sped Up": r"\\bsped\\s*up\\b",
    "Nightcore": r"\\bnightcore\\b",
    "Remix": r"\\bremix\\b",
    "Live": r"\\blive\\b",
    "Acoustic": r"\\bacoustic\\b",
    "Instrumental": r"\\binstrumental\\b",
    "Edit": r"\\bedit\\b",
    "Extended": r"\\bextended\\b",
}

class Track(BaseModel):
    id: str
    title: str
    artist: str
    version: str | None = None
    duration: float | None = None
    artwork: str | None = None
    source: str
    source_url: str
    uploader: str | None = None

def clean(text: str) -> str:
    value = text or ""
    for pattern in NOISE:
        value = re.sub(pattern, " ", value, flags=re.I)
    value = re.sub(r"\\s+", " ", value).strip(" -–—|:·")
    return value

def normalize(raw_title: str, uploader: str = "") -> tuple[str, str, str | None]:
    raw = re.sub(r"\\s+", " ", raw_title or "").strip()
    version = None
    for label, pattern in VERSION_PATTERNS.items():
        if re.search(pattern, raw, flags=re.I):
            version = label if version is None else f"{version} • {label}"
    title = clean(raw)

    parts = re.split(r"\\s+[-–—|:]\\s+", title, maxsplit=1)
    if len(parts) == 2:
        left, right = parts
        if len(left) <= 70 and len(right) <= 100:
            artist, song = left.strip(), right.strip()
        else:
            artist, song = uploader.strip(), title
    else:
        artist, song = uploader.strip(), title

    artist = clean(artist) or "Неизвестный исполнитель"
    song = clean(song) or "Без названия"
    return song, artist, version

def search_sync(term: str, limit: int) -> list[Track]:
    opts: dict[str, Any] = {
        "quiet": True,
        "skip_download": True,
        "extract_flat": True,
        "noplaylist": True,
        "default_search": f"ytsearch{limit}",
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(term, download=False)
    entries = (info or {}).get("entries") or []
    result: list[Track] = []
    for item in entries:
        if not item:
            continue
        raw_title = item.get("title") or ""
        uploader = item.get("uploader") or item.get("channel") or ""
        title, artist, version = normalize(raw_title, uploader)
        url = item.get("webpage_url") or item.get("url") or ""
        if not url:
            continue
        result.append(Track(
            id=str(item.get("id") or url),
            title=title,
            artist=artist,
            version=version,
            duration=item.get("duration"),
            artwork=item.get("thumbnail"),
            source="YouTube",
            source_url=url,
            uploader=uploader or None,
        ))
    return result

@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "rhythm-backend"}

@app.get("/api/search", response_model=list[Track])
async def search(
    q: str = Query(min_length=1, max_length=200),
    limit: int = Query(default=20, ge=1, le=30),
):
    return await asyncio.to_thread(search_sync, q, limit)
