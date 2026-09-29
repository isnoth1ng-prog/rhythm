# Rhythm

Native SwiftUI iOS music player powered by Apple Music MusicKit.

## Features
- Apple Music catalog search for songs and artists
- Artist pages with albums/discography
- ApplicationMusicPlayer playback
- Previous / play-pause / next
- App-local saved library
- Apple Music personal recommendations ("Моя волна")
- Animated karaoke-style lyrics via LRCLIB when synced lyrics are available
- Liquid-glass-inspired SwiftUI UI
- GitHub Actions unsigned IPA build for Windows + Sideloadly

## Important Apple setup
MusicKit requires the app's App ID to have the MusicKit service enabled in Apple Developer, and the user must authorize MusicKit.

The GitHub workflow intentionally builds an unsigned IPA so Sideloadly on Windows can perform the final signing.

## Build
1. Open Actions -> Build Rhythm IPA.
2. Download the Rhythm-unsigned-ipa artifact.
3. Open the IPA in Sideloadly on Windows and sign/install it to the iPhone.

Apple Music playback is subject to Apple Music subscription status and MusicKit entitlement/signing requirements.

## Build status
The main branch triggers the unsigned IPA GitHub Actions workflow.
