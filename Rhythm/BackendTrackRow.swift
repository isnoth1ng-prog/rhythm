import SwiftUI

struct BackendTrackRow: View {
    let track: BackendTrack
    let play: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: track.artwork) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay { Image(systemName: "music.note") }
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
    }
}
