import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: RhythmModel
    @State private var tab = 0
    @State private var playerPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                HomeView().tabItem { Label("Главная", systemImage: "house.fill") }.tag(0)
                WaveView().tabItem { Label("Моя волна", systemImage: "waveform") }.tag(1)
                LibraryView().tabItem { Label("Медиатека", systemImage: "music.note.list") }.tag(2)
            }
            .tint(.white)

            MiniPlayer { playerPresented = true }
                .padding(.horizontal, 12)
                .padding(.bottom, 54)
        }
        .sheet(isPresented: $playerPresented) { PlayerView().environmentObject(model) }
        .alert("Rhythm", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: RhythmModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Rhythm").font(.system(size: 40, weight: .bold, design: .rounded))
                    TextField("Песни, исполнители", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .onSubmit { Task { await model.search() } }

                    if model.isSearching { ProgressView().frame(maxWidth: .infinity) }

                    if !model.tracks.isEmpty {
                        Text("Песни").font(.title2.bold())
                        LazyVStack(spacing: 10) {
                            ForEach(model.tracks) { track in
                                BackendTrackRow(
                                    track: track,
                                    saved: model.savedIDs.contains(track.id),
                                    play: { Task { await model.play(track) } },
                                    toggleSave: { model.toggleSaved(track) }
                                )
                            }
                        }
                    } else if !model.isSearching {
                        VStack(spacing: 10) {
                            Image(systemName: "waveform").font(.system(size: 48)).foregroundStyle(.secondary)
                            Text("Найди свою музыку").font(.title3.bold())
                            Text("Поиск работает через внешний Rhythm Backend с нормализацией метаданных.")
                                .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

struct WaveView: View {
    @EnvironmentObject private var model: RhythmModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Моя волна").font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("Персональная лента Rhythm на основе сохранённых треков и истории.")
                        .foregroundStyle(.secondary)
                    Text("Рекомендации подключим поверх того же backend после стабилизации поиска и плеера.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var model: RhythmModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Медиатека").font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("\(model.savedIDs.count) сохранённых треков").foregroundStyle(.secondary)
                    Text("Избранное хранится локально в Rhythm.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var model: RhythmModel
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                if let current = model.currentTrack {
                    ArtworkURLView(url: current.artwork, size: 44)
                    VStack(alignment: .leading) {
                        Text(current.title).font(.subheadline.bold()).lineLimit(1)
                        Text(current.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button(action: model.togglePlayPause) {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "waveform")
                    Text("Сейчас играет…").font(.subheadline.bold())
                    Spacer()
                }
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12)) }
        }
        .buttonStyle(.plain)
    }
}
