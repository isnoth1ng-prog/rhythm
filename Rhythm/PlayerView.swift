import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var model: RhythmModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Capsule().fill(.secondary.opacity(0.5)).frame(width: 42, height: 5).padding(.top, 8)
                Text("Сейчас играет…").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

                if let track = model.currentTrack {
                    ArtworkURLView(url: track.artwork, size: 320).shadow(radius: 30)

                    VStack(spacing: 5) {
                        Text(track.title).font(.title2.bold()).lineLimit(2).multilineTextAlignment(.center)
                        Text(track.subtitle).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center)
                    }

                    VStack(spacing: 5) {
                        Slider(
                            value: Binding(
                                get: { model.duration > 0 ? model.playbackTime / model.duration : 0 },
                                set: { model.seek(to: $0) }
                            ),
                            in: 0...1
                        )
                        .tint(.white)
                        HStack {
                            Text(formatTime(model.playbackTime))
                            Spacer()
                            Text(formatTime(model.duration))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 38) {
                        Button { model.skip(seconds: -10) } label: {
                            Image(systemName: "gobackward.10").font(.title2)
                        }
                        Button(action: model.togglePlayPause) {
                            Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 62))
                        }
                        Button { model.skip(seconds: 30) } label: {
                            Image(systemName: "goforward.30").font(.title2)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        ActionButton(title: "Текст", icon: "quote.bubble.fill") { showLyrics = true }
                        ActionButton(title: "Моя волна", icon: "waveform") { dismiss() }
                        ActionButton(
                            title: model.savedIDs.contains(track.id) ? "Сохранено" : "Сохранить",
                            icon: model.savedIDs.contains(track.id) ? "heart.fill" : "heart"
                        ) { model.toggleSaved(track) }
                    }
                } else {
                    ContentUnavailableView("Ничего не играет", systemImage: "music.note", description: Text("Выбери трек на главной."))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.black.ignoresSafeArea())
            .sheet(isPresented: $showLyrics) {
                if let track = model.currentTrack {
                    LyricsView(title: track.title, artist: track.artist)
                        .presentationDetents([.large])
                }
            }
        }
    }

    private func formatTime(_ value: Double) -> String {
        let seconds = max(0, Int(value.isFinite ? value : 0))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
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
