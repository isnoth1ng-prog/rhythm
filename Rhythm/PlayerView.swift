import SwiftUI
import MusicKit

struct PlayerView: View {
    @EnvironmentObject private var model: RhythmModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false

    private var currentSong: Song? {
        guard let item = model.player.queue.currentEntry?.item else { return nil }
        if case .song(let song) = item { return song }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Capsule().fill(.secondary.opacity(0.5)).frame(width: 42, height: 5).padding(.top, 8)
                Text("Сейчас играет…").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

                if let entry = model.player.queue.currentEntry {
                    ArtworkView(artwork: entry.artwork, size: 320).shadow(radius: 30)

                    VStack(spacing: 5) {
                        Text(entry.title).font(.title2.bold()).lineLimit(1)
                        Text(entry.subtitle ?? "").foregroundStyle(.secondary).lineLimit(1)
                    }

                    ProgressSlider(player: model.player)

                    HStack(spacing: 38) {
                        Button { Task { try? await model.player.skipToPreviousEntry() } } label: {
                            Image(systemName: "backward.fill").font(.title2)
                        }
                        Button {
                            Task {
                                if model.player.state.playbackStatus == .playing { model.player.pause() }
                                else { try? await model.player.play() }
                            }
                        } label: {
                            Image(systemName: model.player.state.playbackStatus == .playing ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 62))
                        }
                        Button { Task { try? await model.player.skipToNextEntry() } } label: {
                            Image(systemName: "forward.fill").font(.title2)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        ActionButton(title: "Текст", icon: "quote.bubble.fill") { showLyrics = true }
                        ActionButton(title: "Моя волна", icon: "waveform") {
                            Task { await model.loadRecommendations(); dismiss() }
                        }
                        ActionButton(
                            title: model.savedIDs.contains(entry.id) ? "Сохранено" : "Сохранить",
                            icon: model.savedIDs.contains(entry.id) ? "heart.fill" : "heart"
                        ) {
                            if let song = currentSong { model.toggleSaved(song) }
                        }
                    }
                } else {
                    ContentUnavailableView("Ничего не играет", systemImage: "music.note", description: Text("Выбери трек на главной."))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.black.ignoresSafeArea())
            .sheet(isPresented: $showLyrics) {
                if let entry = model.player.queue.currentEntry {
                    LyricsView(title: entry.title, artist: entry.subtitle ?? "")
                        .presentationDetents([.large])
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct ProgressSlider: View {
    let player: ApplicationMusicPlayer
    @State private var progress: Double = 0

    private var currentDuration: TimeInterval {
        guard let item = player.queue.currentEntry?.item else { return 0 }
        switch item {
        case .song(let song): return song.duration ?? 0
        case .musicVideo: return 0
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            Slider(value: Binding(
                get: { progress },
                set: { newValue in
                    progress = newValue
                    if currentDuration > 0 { player.playbackTime = currentDuration * newValue }
                }
            ), in: 0...1)
            .tint(.white)
            HStack {
                Text(formatTime(player.playbackTime))
                Spacer()
                Text(formatTime(currentDuration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .task {
            while !Task.isCancelled {
                if currentDuration > 0, player.playbackTime.isFinite {
                    progress = min(max(player.playbackTime / currentDuration, 0), 1)
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct LyricsView: View {
    let title: String
    let artist: String
    @State private var lines: [LyricLine] = []
    @State private var synced = false
    @State private var loading = true
    @State private var currentTime: TimeInterval = 0

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Text(title).font(.largeTitle.bold())
                        Text(artist).foregroundStyle(.secondary)
                        Divider().padding(.vertical, 8)

                        if loading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                        } else if lines.isEmpty {
                            ContentUnavailableView("Текст не найден", systemImage: "text.quote")
                        } else {
                            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                let active = isActive(index)
                                Text(line.text)
                                    .font(.system(size: active ? 28 : 23, weight: active ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(active ? .white : .secondary)
                                    .scaleEffect(active ? 1.02 : 1)
                                    .animation(.easeInOut(duration: 0.25), value: active)
                                    .id(line.id)
                            }
                        }
                    }
                    .padding(24)
                }
                .task {
                    let result = await LyricsService.fetch(title: title, artist: artist, duration: nil)
                    lines = result.lines
                    synced = result.synced
                    loading = false
                    startClock()
                }
                .onChange(of: currentTime) { _, _ in
                    if let line = activeLine {
                        withAnimation { proxy.scrollTo(line.id, anchor: .center) }
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(synced ? "Синхронизировано" : "Текст")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var activeLine: LyricLine? {
        lines.last(where: { $0.start <= currentTime })
    }

    private func isActive(_ index: Int) -> Bool {
        guard index < lines.count else { return false }
        return lines[index].id == activeLine?.id
    }

    private func startClock() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                let player = ApplicationMusicPlayer.shared
                if player.playbackTime.isFinite { currentTime = player.playbackTime }
            }
        }
    }
}
