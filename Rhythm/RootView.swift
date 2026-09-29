import SwiftUI
import MusicKit

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
        .task {
            if model.authorization != .authorized { await model.requestAccess() }
        }
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

                    if !model.artists.isEmpty {
                        Text("Исполнители").font(.title2.bold())
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(model.artists) { artist in
                                    NavigationLink { ArtistView(artist: artist) } label: {
                                        GlassCard {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Image(systemName: "person.crop.circle.fill").font(.system(size: 42))
                                                Text(artist.name).font(.headline).lineLimit(1)
                                            }
                                            .frame(width: 150, alignment: .leading)
                                        }
                                        .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }

                    if !model.songs.isEmpty {
                        Text("Песни").font(.title2.bold())
                        LazyVStack(spacing: 10) {
                            ForEach(model.songs) { song in
                                SongRow(
                                    song: song,
                                    saved: model.savedIDs.contains(song.id.rawValue),
                                    play: { Task { await model.play(song) } },
                                    toggleSave: { model.toggleSaved(song) }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "waveform").font(.system(size: 48)).foregroundStyle(.secondary)
                            Text("Найди свою музыку").font(.title3.bold())
                            Text("Ищи песни и исполнителей в каталоге Apple Music.")
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
                    Text("Персональные рекомендации Apple Music на основе медиатеки и истории прослушивания.")
                        .foregroundStyle(.secondary)

                    if model.recommendations.isEmpty {
                        Button("Загрузить рекомендации") { Task { await model.loadRecommendations() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        ForEach(model.recommendations, id: \.id) { recommendation in
                            RecommendationSectionView(recommendation: recommendation)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .task {
                if model.recommendations.isEmpty { await model.loadRecommendations() }
            }
        }
    }
}

struct RecommendationSectionView: View {
    let recommendation: MusicPersonalRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recommendation.title ?? "Для тебя").font(.title3.bold())
            if let reason = recommendation.reason {
                Text(reason).font(.subheadline).foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(recommendation.albums.prefix(10))) { album in
                        VStack(alignment: .leading, spacing: 7) {
                            ArtworkView(artwork: album.artwork, size: 140)
                            Text(album.title).font(.headline).lineLimit(2)
                            Text(album.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                    ForEach(Array(recommendation.playlists.prefix(10))) { playlist in
                        VStack(alignment: .leading, spacing: 7) {
                            ArtworkView(artwork: playlist.artwork, size: 140)
                            Text(playlist.name).font(.headline).lineLimit(2)
                            Text("Плейлист").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
            }
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
                    Text("Сохранённые треки хранятся локально в Rhythm. Добавление в системную библиотеку Apple Music можно подключить отдельной кнопкой после настройки MusicKit entitlement.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

struct ArtistView: View {
    let artist: Artist
    @State private var albums: [Album] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(artist.name).font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Дискография").font(.title2.bold())

                if loading {
                    ProgressView()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(albums) { album in
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    ArtworkView(artwork: album.artwork, size: 150)
                                    Text(album.title).font(.headline).lineLimit(2)
                                    Text(album.artistName).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            do {
                var request = MusicCatalogSearchRequest(term: artist.name, types: [Album.self])
                request.limit = 50
                let response = try await request.response()
                albums = Array(response.albums)
            } catch { }
            loading = false
        }
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var model: RhythmModel
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                if let current = model.player.queue.currentEntry {
                    ArtworkView(artwork: current.artwork, size: 44)
                    VStack(alignment: .leading) {
                        Text(current.title).font(.subheadline.bold()).lineLimit(1)
                        Text(current.subtitle ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button {
                        Task {
                            if model.player.state.playbackStatus == .playing { model.player.pause() }
                            else { try? await model.player.play() }
                        }
                    } label: {
                        Image(systemName: model.player.state.playbackStatus == .playing ? "pause.fill" : "play.fill")
                            .font(.title3)
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
