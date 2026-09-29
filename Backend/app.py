from __future__ import annotations

import asyncio
import re
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from yt_dlp import YoutubeDL

app = FastAPI(title="Rhythm Backend", version="1.1.0")

NOISE = [
    r"\[[^\]]*(?:official|video|audio|lyrics|hd|4k|premiere|премьера|клип)[^\]]*\]",
    r"\([^\)]*(?:official|video|audio|lyrics|prod(?:uced)?\.?\s*by|премьера|клип)[^\)]*\)",
    r"#\w+",
    r"\b(?:official|music video|official audio|full hd|4k|hq|lyrics|lyric video|премьера|клип|скачать|download)\b",
    r"[🔥💥⭐️✨🎵🎶❤️]+",
]

VERSION_PATTERNS = {
    "Slowed + Reverb": r"\bslowed(?:\s*\+\s*|\s+and\s+)reverb\b",
    "Sped Up": r"\bsped\s*up\b",
    "Nightcore": r"\bnightcore\b",
    "Remix": r"\bremix\b",
    "Live": r"\blive\b",
    "Acoustic": r"\bacoustic\b",
    "Instrumental": r"\binstrumental\b",
    "Edit": r"\bedit\b",
    "Extended": r"\bextended\b",
}

PENALTY_PATTERNS = {
    "reaction": -70,
    "реакция": -70,
    "review": -55,
    "обзор": -55,
    "news": -60,
    "новости": -60,
    "podcast": -45,
    "подкаст": -45,
    "interview": -45,
    "интервью": -45,
    "gameplay": -70,
    "shorts": -35,
    "compilation": -30,
    "сборник": -30,
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
    value = re.sub(r"\s+", " ", value).strip(" -–—|:·")
    return value

def tokens(text: str) -> set[str]:
    return {x for x in re.findall(r"[\wёа-я]+", (text or "").lower()) if len(x) > 1}

def normalize(raw_title: str, uploader: str = "", query: str = "") -> tuple[str, str, str | None]:
    raw = re.sub(r"\s+", " ", raw_title or "").strip()
    version_parts = []
    for label, pattern in VERSION_PATTERNS.items():
        if re.search(pattern, raw, flags=re.I):
            version_parts.append(label)
    version = " • ".join(version_parts) or None
    title = clean(raw)

    parts = re.split(r"\s+[-–—|:]\s+", title, maxsplit=1)
    if len(parts) == 2:
        left, right = (clean(x) for x in parts)
        artist, song = left, right
    else:
        # Many YouTube music uploads omit "Artist - Title". Prefer the query's
        # first meaningful token group over blindly exposing the channel name.
        qparts = re.split(r"\s+[-–—|:]\s+", clean(query), maxsplit=1)
        if len(qparts) == 2:
            artist, song = clean(qparts[0]), clean(qparts[1])
        else:
            artist, song = clean(uploader), title

    artist = artist or "Неизвестный исполнитель"
    song = song or "Без названия"
    return song, artist, version

def score(item: dict[str, Any], query: str, title: str, artist: str) -> float:
    hay = f"{item.get('title') or ''} {item.get('uploader') or ''} {item.get('channel') or ''}".lower()
    q = tokens(query)
    score_value = 0.0
    score_value += len(q & tokens(hay)) * 12
    if tokens(artist) & tokens(item.get("uploader") or ""):
        score_value += 18
    if re.search(r"\b(?:official|vevo|topic)\b", hay, re.I):
        score_value += 8
    for word, penalty in PENALTY_PATTERNS.items():
        if word in hay:
            score_value += penalty
    duration = item.get("duration")
    if isinstance(duration, (int, float)):
        if duration < 45:
            score_value -= 18
        elif duration > 900:
            score_value -= 12
        else:
            score_value += 6
    return score_value

def search_sync(term: str, limit: int) -> list[Track]:
    fetch_limit = min(max(limit * 2, 20), 40)
    opts: dict[str, Any] = {
        "quiet": True,
        "skip_download": True,
        "extract_flat": True,
        "noplaylist": True,
        "default_search": f"ytsearch{fetch_limit}",
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(term, download=False)

    entries = (info or {}).get("entries") or []
    ranked: list[tuple[float, Track]] = []
    seen: set[str] = set()

    for item in entries:
        if not item:
            continue
        raw_title = item.get("title") or ""
        uploader = item.get("uploader") or item.get("channel") or ""
        title, artist, version = normalize(raw_title, uploader, term)
        url = item.get("webpage_url") or item.get("url") or ""
        if not url:
            continue

        key = re.sub(r"[^\wёа-я]+", "", f"{artist.lower()}|{title.lower()}|{version or ''}")
        if key in seen:
            continue
        seen.add(key)

        track = Track(
            id=str(item.get("id") or url),
            title=title,
            artist=artist,
            version=version,
            duration=item.get("duration"),
            artwork=item.get("thumbnail"),
            source="YouTube",
            source_url=url,
            uploader=uploader or None,
        )
        ranked.append((score(item, term, title, artist), track))

    ranked.sort(key=lambda pair: pair[0], reverse=True)
    return [track for _, track in ranked[:limit]]

def resolve_sync(url: str) -> str:
    opts: dict[str, Any] = {
        "quiet": True,
        "skip_download": True,
        "format": "bestaudio/best",
        "noplaylist": True,
    }
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    direct = info.get("url") if info else None
    if not direct:
        raise ValueError("No playable stream returned")
    return direct

@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "rhythm-backend"}

@app.get("/api/search", response_model=list[Track])
async def search(
    q: str = Query(min_length=1, max_length=200),
    limit: int = Query(default=20, ge=1, le=30),
):
    return await asyncio.to_thread(search_sync, q, limit)

@app.get("/api/resolve")
async def resolve(url: str = Query(min_length=10, max_length=2000)) -> dict[str, str]:
    try:
        direct = await asyncio.to_thread(resolve_sync, url)
        return {"url": direct}
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Stream resolution failed: {exc}") from exc
