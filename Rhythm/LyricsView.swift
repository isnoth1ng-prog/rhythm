import SwiftUI

struct LyricsView: View {
    @EnvironmentObject private var model: RhythmModel
    let title: String
    let artist: String

    @State private var result = LyricsResult(lines: [], synced: false)
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if loading {
                            ProgressView("Ищу текст…")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        } else if result.lines.isEmpty {
                            ContentUnavailableView(
                                "Текст не найден",
                                systemImage: "quote.bubble",
                                description: Text("Для этого трека LRCLIB не вернул текст.")
                            )
                        } else {
                            ForEach(Array(result.lines.enumerated()), id: \.element.id) { index, line in
                                Text(line.text)
                                    .font(.system(size: 25, weight: .bold, design: .rounded))
                                    .foregroundStyle(isActive(index) ? .primary : .secondary)
                                    .opacity(isActive(index) ? 1 : 0.55)
                                    .scaleEffect(isActive(index) ? 1.01 : 1)
                                    .animation(.easeOut(duration: 0.2), value: model.playbackTime)
                                    .id(line.id)
                            }
                        }
                    }
                    .padding(22)
                }
                .scrollIndicators(.hidden)
                .background(Color.black.ignoresSafeArea())
                .onChange(of: model.playbackTime) { _, _ in
                    guard let active = activeIndex else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(result.lines[active].id, anchor: .center)
                    }
                }
            }
            .navigationTitle("Текст")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                result = await LyricsService.fetch(
                    title: title,
                    artist: artist,
                    duration: model.duration
                )
                loading = false
            }
        }
        .preferredColorScheme(.dark)
    }

    private var activeIndex: Int? {
        guard result.synced, !result.lines.isEmpty else { return nil }
        var current: Int?
        for (index, line) in result.lines.enumerated() {
            if line.start <= model.playbackTime {
                current = index
            } else {
                break
            }
        }
        return current
    }

    private func isActive(_ index: Int) -> Bool {
        activeIndex == index
    }
}
