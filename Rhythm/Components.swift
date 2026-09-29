import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

struct ArtworkURLView: View {
    let url: URL?
    var size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(.quaternary)
                    .overlay { Image(systemName: "music.note").font(.system(size: size * 0.2)) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
    }
}

struct BackendTrackRow: View {
    let track: BackendTrack
    let saved: Bool
    let play: () -> Void
    let toggleSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkURLView(url: track.artwork, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                Text(track.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: toggleSave) {
                Image(systemName: saved ? "heart.fill" : "heart")
                    .foregroundStyle(saved ? .pink : .primary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
    }
}
