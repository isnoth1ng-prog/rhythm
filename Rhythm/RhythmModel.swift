import Foundation
import MusicKit
import SwiftUI

@MainActor
final class RhythmModel: ObservableObject {
    @Published var authorization: MusicAuthorization.Status = .notDetermined
    @Published var searchText = ""
    @Published var songs: [Song] = []
    @Published var artists: [Artist] = []
    @Published var recommendations: [MusicPersonalRecommendation] = []
    @Published var savedIDs: Set<String> = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    let player = ApplicationMusicPlayer.shared
    private let savedKey = "rhythm.saved.ids"

    init() {
        savedIDs = Set(UserDefaults.standard.stringArray(forKey: savedKey) ?? [])
        authorization = MusicAuthorization.currentStatus
    }

    func requestAccess() async {
        authorization = await MusicAuthorization.request()
    }

    func search() async {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            songs = []
            artists = []
            return
        }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self, Artist.self])
            request.limit = 20
            let response = try await request.response()
            songs = Array(response.songs)
            artists = Array(response.artists)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func play(_ song: Song) async {
        do {
            player.queue = [song]
            try await player.prepareToPlay()
            try await player.play()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSaved(_ song: Song) {
        let id = song.id.rawValue
        if savedIDs.contains(id) {
            savedIDs.remove(id)
        } else {
            savedIDs.insert(id)
        }
        UserDefaults.standard.set(Array(savedIDs), forKey: savedKey)
    }

    func loadRecommendations() async {
        do {
            var request = MusicPersonalRecommendationsRequest()
            request.limit = 30
            let response = try await request.response()
            recommendations = Array(response.recommendations)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
