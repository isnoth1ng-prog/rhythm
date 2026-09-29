# Rhythm Windows Backend

This backend is intended to run on the user's Windows PC while the iPhone accesses it over the public internet.

## One-time setup

1. Run `start-rhythm.bat`.
2. If prompted, sign in to Tailscale in the browser.
3. Approve Funnel/HTTPS if Tailscale asks for it.
4. The script prints a stable `https://...ts.net` address.

The iPhone does **not** need to be on the same Wi-Fi and does not need Tailscale installed when using Funnel. Tailscale Funnel publishes the local backend through HTTPS while the PC is online.

## Daily use

Run `start-rhythm.bat`. Keep the PC on while using Rhythm.

Use `stop-rhythm.bat` to stop the backend and public tunnel.

## Local API

- `GET /health`
- `GET /api/search?q=artist%20song`
- `GET /api/resolve?url=...`

The backend does not implement cookies, token extraction, or protection bypasses. It uses normal yt-dlp extraction.
