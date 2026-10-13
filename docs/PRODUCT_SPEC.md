# Rhythm — cross-platform rewrite plan

## Product direction
Rhythm keeps its name. This branch is a clean cross-platform rewrite for iOS and Android; the existing SwiftUI app on `main` is preserved as a reference and is not deleted or overwritten.

## Proposed stack
- React Native + Expo + TypeScript for shared iOS/Android UI and application logic.
- Expo development builds / native modules where platform audio capabilities require them.
- A provider-adapter layer so catalog search, metadata normalization, availability and playback are not hard-coded to one service.
- GitHub Actions for automated checks and documented build workflows.

Final audio library and playback packages must be validated with a small proof-of-concept before committing to the architecture.

## Product principles
- Distinctive Rhythm design system; do not clone Apple Music or use a generic starter template.
- Search results prioritize exact track title and artist matches.
- Normalize Unicode, case, whitespace and common title punctuation for matching; retain the provider's original metadata for display/attribution.
- Filter likely noise (unrelated uploads, obvious re-uploads, karaoke, slowed/reverb, nightcore, snippets, lyric videos and remixes when the user asks for the original). Do not claim a track is official unless provider metadata supports that.
- Never fabricate metadata or hide source/creator attribution required by a provider.
- User library stores Rhythm's own saved IDs/references and metadata; it does not download or copy provider audio unless expressly allowed by the source's terms.
- Use official APIs / permitted player integrations only. Do not extract or proxy audio streams in ways that bypass provider restrictions.

## Provider constraints to account for
- YouTube Data API can search videos and return metadata, but search API access is not permission to extract an audio-only stream. YouTube playback must use a permitted YouTube player/integration and follow applicable branding and playback policies. A custom background audio-only experience must not be promised based on YouTube search alone.
- SoundCloud's API supports track search and has playback options for eligible tracks, but access credentials/approval and terms must be confirmed. A custom player requires required creator/SoundCloud attribution and links. If API access is not granted or terms do not fit the intended app, keep SoundCloud as an outbound/open-in-provider option rather than bypassing restrictions.
- Keep provider-specific playback capabilities explicit: for example, background playback, lock-screen controls, track duration and seeking may differ by source.

References:
- YouTube Search API: https://developers.google.com/youtube/v3/docs/search/list
- YouTube API developer policies: https://developers.google.com/youtube/terms/developer-policies
- SoundCloud API guide: https://developers.soundcloud.com/docs/
- SoundCloud API terms: https://developers.soundcloud.com/docs/api/terms-of-use

## MVP milestones
1. Repository audit and cross-platform app shell.
2. Design tokens, navigation and polished placeholder screens with realistic sample data.
3. Search provider interface plus metadata normalization/ranking and noise filters, covered by tests.
4. Verify SoundCloud API access and implement an approved search/playback proof-of-concept.
5. Implement a compliant YouTube result/player flow if useful; do not treat YouTube as a guaranteed audio-only provider.
6. Playback queue, mini-player, saved library, history and error states.
7. Background audio, lock-screen controls and interruption handling where the selected provider and native platform APIs permit it.
8. Lyrics where an appropriate source and usage terms are available.
9. iOS/Android device testing, accessibility, performance, secrets management and release builds.

## Acceptance criteria for the first prototype
- Runs as a development build on Android and has a documented iOS build path.
- Search results show title, creator/channel, source and a link to the source.
- Ranking favors exact artist + title matches and marks uncertain matches instead of silently claiming authenticity.
- Unsupported playback states are explained clearly; no fake play button.
- No provider credentials are committed to the repository.
- Existing `main` branch remains unchanged by this rewrite work.
